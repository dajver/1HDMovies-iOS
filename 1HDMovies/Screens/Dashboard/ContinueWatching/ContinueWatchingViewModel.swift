import Foundation
import os

private let log = Logger(subsystem: "com.dajver.one.hd", category: "ContinueWatching")

struct ContinueWatchingItem: Identifiable {
    let id: String          // show linkToDetails
    let showName: String
    let thumbnail: String
    let episodes: [MovieEpisodesDataModel]   // full ordered list across all seasons
    let nextIndex: Int       // index of the next episode to watch
    let lastWatchedAt: Date  // for ordering the row

    var nextEpisode: MovieEpisodesDataModel { episodes[nextIndex] }
    var remaining: Int { episodes.count - nextIndex }
}

@Observable
class ContinueWatchingViewModel {
    var items: [ContinueWatchingItem] = []

    @MainActor
    func refresh() {
        let watched = WatchedEpisodeRepository.shared.allWatchedEpisodeLinks()
        let dates = WatchedEpisodeRepository.shared.watchedDates()
        let shows = FavoriteRepository.shared.fetchAllFavoriteModels().filter { $0.movieType == .tvShow }

        // TEMP DIAGNOSTIC
        for link in watched { log.info("WATCHED: \(link)") }

        var result: [ContinueWatchingItem] = []
        for show in shows {
            let episodes = (show.seasonsList ?? []).flatMap { $0.episodes }
            guard !episodes.isEmpty else {
                log.info("\(show.name): no stored episodes")
                continue
            }

            // Furthest-progress watched episode (not the most recent by time) so we
            // never propose earlier seasons the user skipped past.
            var maxWatchedIndex = -1
            for (index, episode) in episodes.enumerated() where watched.contains(episode.link) {
                maxWatchedIndex = index
            }
            let matchedCount = episodes.filter { watched.contains($0.link) }.count
            log.info("\(show.name): \(episodes.count) stored episodes, \(matchedCount) watched, maxIndex \(maxWatchedIndex)")
            // TEMP DIAGNOSTIC: dump stored links for small, unmatched shows
            if matchedCount == 0 && episodes.count <= 12 {
                for episode in episodes { log.info("STORED [\(show.name)]: \(episode.link)") }
            }

            guard maxWatchedIndex >= 0 else { continue }            // not started — excluded
            let nextIndex = maxWatchedIndex + 1
            guard nextIndex < episodes.count else { continue }      // caught up / finished

            let lastWatchedAt = dates[episodes[maxWatchedIndex].link] ?? .distantPast
            result.append(ContinueWatchingItem(
                id: show.linkToDetails,
                showName: show.name,
                thumbnail: show.thumbnail,
                episodes: episodes,
                nextIndex: nextIndex,
                lastWatchedAt: lastWatchedAt
            ))
        }

        log.info("ContinueWatching: \(shows.count) favorited TV shows, \(watched.count) watched episodes -> \(result.count) items")
        items = result.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
    }
}
