import Foundation
import SwiftData

/// Re-keys every stored site URL to the currently-live domain after a site move.
///
/// Requests self-heal at fetch time (`SiteDomain.live` in `HttpClient`), but
/// identity doesn't: favorites, watched marks, episode snapshots and playback
/// progress are keyed by full URLs carrying whatever domain was live when they
/// were written, so freshly-scraped links on the new host never match them —
/// watched state looks lost, continue-watching forgets positions. This pass
/// rewrites the stored records themselves; the cloud copies are re-keyed in
/// place by `FirebaseSyncService.migrateStoredLinks()` before `syncAll`.
///
/// Collision rule: if a record already exists under the live-host key (the user
/// re-saved it after the move), that one is necessarily newer — the old-host
/// record is dropped in its favor.
@MainActor
enum LinkMigration {

    /// Rewrites all stored records to the live host. Returns whether anything changed.
    @discardableResult
    static func run(modelContext context: ModelContext) -> Bool {
        let favorites = migrateFavorites(context)
        let watched = migrateKeyed(context, WatchedMovie.self, \.linkToDetails)
        let episodes = migrateKeyed(context, WatchedEpisode.self, \.episodeLink)
        let progress = migrateKeyed(context, PlaybackProgress.self, \.contentLink)
        let notifications = migrateKeyed(context, ShowNotification.self, \.showLinkToDetails)
        let snapshots = migrateSnapshots(context)
        let changed = favorites || watched || episodes || progress || notifications || snapshots
        if changed { try? context.save() }
        return changed
    }

    /// The live-host rewrite of `value`, or nil if it's already current (or not a site URL).
    private static func moved(_ value: String) -> String? {
        let live = SiteDomain.live(value)
        return live == value ? nil : live
    }

    /// Re-keys a model whose unique key is a single URL attribute.
    private static func migrateKeyed<T: PersistentModel>(
        _ context: ModelContext, _ type: T.Type, _ key: ReferenceWritableKeyPath<T, String>
    ) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
        var links = Set(all.map { $0[keyPath: key] })
        var changed = false
        for item in all {
            let old = item[keyPath: key]
            guard let live = moved(old) else { continue }
            links.remove(old)
            if links.contains(live) {
                context.delete(item)
            } else {
                links.insert(live)
                item[keyPath: key] = live
            }
            changed = true
        }
        return changed
    }

    private static func migrateFavorites(_ context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<FavoriteMovie>())) ?? []
        var links = Set(all.map { $0.linkToDetails })
        var changed = false
        for favorite in all {
            if let live = moved(favorite.linkToDetails) {
                links.remove(favorite.linkToDetails)
                if links.contains(live) {
                    context.delete(favorite)
                    changed = true
                    continue
                }
                links.insert(live)
                favorite.linkToDetails = live
                changed = true
            }
            if let live = moved(favorite.linkToWatch) {
                favorite.linkToWatch = live
                changed = true
            }
            if let live = moved(favorite.watchMovieLinkWithEpisodeId) {
                favorite.watchMovieLinkWithEpisodeId = live
                changed = true
            }
            if let seasons = favorite.seasonsList {
                var seasonsChanged = false
                let migrated = seasons.map { season in
                    MovieSeasonDataModel(
                        seasonId: season.seasonId,
                        seasonNumber: season.seasonNumber,
                        episodes: season.episodes.map { episode in
                            guard let live = moved(episode.link) else { return episode }
                            seasonsChanged = true
                            return MovieEpisodesDataModel(episodeNumber: episode.episodeNumber,
                                                          episodeName: episode.episodeName,
                                                          link: live)
                        }
                    )
                }
                if seasonsChanged {
                    favorite.seasonsJson = try? JSONEncoder().encode(migrated)
                    changed = true
                }
            }
        }
        return changed
    }

    private static func migrateSnapshots(_ context: ModelContext) -> Bool {
        var changed = migrateKeyed(context, ShowEpisodeSnapshot.self, \.linkToDetails)
        let all = (try? context.fetch(FetchDescriptor<ShowEpisodeSnapshot>())) ?? []
        for snapshot in all {
            let live = snapshot.knownEpisodeLinks.map { SiteDomain.live($0) }
            if live != snapshot.knownEpisodeLinks {
                snapshot.knownEpisodeLinks = live
                changed = true
            }
        }
        return changed
    }
}
