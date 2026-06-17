import Foundation
import SwiftData
import Observation
import os

private let log = Logger(subsystem: "com.dajver.one.hd", category: "NewEpisodes")

@Observable
@MainActor
final class NewEpisodeService {
    static let shared = NewEpisodeService()

    /// Don't re-check a show more often than this (also limits Firebase writes).
    private let recheckInterval: TimeInterval = 6 * 3600

    var modelContext: ModelContext?
    var notifications: [ShowNotification] = []
    var unreadCount: Int = 0
    var isChecking = false

    private init() {}

    /// On launch: for each favorited TV show, fetch the current episode list and
    /// compare it to the last-known snapshot. Episodes that appeared since then
    /// become "new episode" notifications. The first time a show is seen we only
    /// record a baseline (no notifications), so there's no spam on first run.
    func checkForNewEpisodes(force: Bool = false) async {
        guard let context = modelContext, !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let shows = FavoriteRepository.shared.fetchAllFavoriteModels().filter { $0.movieType == .tvShow }
        log.info("Checking \(shows.count) favorited TV shows for new episodes")
        let now = Date()

        for show in shows {
            let link = show.linkToDetails
            var descriptor = FetchDescriptor<ShowEpisodeSnapshot>(
                predicate: #Predicate { $0.linkToDetails == link }
            )
            descriptor.fetchLimit = 1
            let snapshot = try? context.fetch(descriptor).first

            // Throttle: skip shows that were checked recently (possibly by another device via sync).
            // A manual refresh (force) or a favorite still needing repair (empty name,
            // saved before parsing fixes) bypasses the throttle.
            let needsRepair = show.name.isEmpty
            if !force, !needsRepair, let snapshot, now.timeIntervalSince(snapshot.lastCheckedAt) < recheckInterval {
                continue
            }

            do {
                let details = try await MovieDetailsRepository.shared.fetchDetails(url: link)
                let currentEpisodes = (details.seasonsList ?? []).flatMap { $0.episodes }
                guard !currentEpisodes.isEmpty else { continue }
                let currentLinks = currentEpisodes.map { $0.link }

                // Keep the favorite's stored name/thumbnail/episode list fresh so
                // Continue Watching shows the right title and newly-added episodes.
                FavoriteRepository.shared.refreshFavoriteIfNeeded(details)

                if let snapshot {
                    let known = Set(snapshot.knownEpisodeLinks)
                    let newEpisodes = currentEpisodes.filter { !known.contains($0.link) }
                    if !newEpisodes.isEmpty {
                        upsertNotification(show: show, newEpisodes: newEpisodes, context: context)
                        log.info("\(newEpisodes.count) new episodes for \(show.name)")
                    }
                    snapshot.knownEpisodeLinks = currentLinks
                    snapshot.lastCheckedAt = now
                } else {
                    // First time seeing this show — record a baseline, no notifications.
                    let new = ShowEpisodeSnapshot(linkToDetails: link, knownEpisodeLinks: currentLinks)
                    context.insert(new)
                }

                // Push the updated snapshot to the cloud (no-op when signed out).
                Task { await FirebaseSyncService.shared.uploadEpisodeSnapshot(
                    linkToDetails: link, knownEpisodeLinks: currentLinks, lastCheckedAt: now) }
            } catch {
                log.error("Failed to check \(show.name): \(error.localizedDescription)")
                continue
            }
        }

        try? context.save()
        refresh()
    }

    func refresh() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ShowNotification>(
            sortBy: [SortDescriptor(\.detectedAt, order: .reverse)]
        )
        notifications = (try? context.fetch(descriptor)) ?? []
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    func markAllRead() {
        guard let context = modelContext else { return }
        let readLinks = notifications.filter { !$0.isRead }.map { $0.showLinkToDetails }
        guard !readLinks.isEmpty else { return }
        for notification in notifications where !notification.isRead {
            notification.isRead = true
        }
        try? context.save()
        unreadCount = 0
        Task { await FirebaseSyncService.shared.markShowNotificationsRead(readLinks) }
    }

    /// One notification per show. Accumulates the count while unread; a fresh
    /// batch (after the user has read it) resets the count.
    private func upsertNotification(show: FavoriteMovie, newEpisodes: [MovieEpisodesDataModel], context: ModelContext) {
        guard let latest = newEpisodes.last else { return }
        let link = show.linkToDetails
        var descriptor = FetchDescriptor<ShowNotification>(
            predicate: #Predicate { $0.showLinkToDetails == link }
        )
        descriptor.fetchLimit = 1

        let notification: ShowNotification
        if let existing = try? context.fetch(descriptor).first {
            notification = existing
            notification.newEpisodeCount = existing.isRead ? newEpisodes.count
                                                           : existing.newEpisodeCount + newEpisodes.count
            notification.latestEpisodeNumber = latest.episodeNumber
            notification.latestEpisodeName = latest.episodeName
            notification.detectedAt = Date()
            notification.isRead = false
        } else {
            notification = ShowNotification(
                showLinkToDetails: show.linkToDetails,
                showName: show.name,
                showThumbnail: show.thumbnail,
                newEpisodeCount: newEpisodes.count,
                latestEpisodeNumber: latest.episodeNumber,
                latestEpisodeName: latest.episodeName
            )
            context.insert(notification)
        }

        Task { await FirebaseSyncService.shared.uploadShowNotification(notification) }
    }
}
