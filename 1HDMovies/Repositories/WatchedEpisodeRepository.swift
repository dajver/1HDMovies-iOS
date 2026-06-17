import Foundation
import SwiftData

@MainActor
class WatchedEpisodeRepository {
    static let shared = WatchedEpisodeRepository()

    var modelContext: ModelContext?

    func allWatchedEpisodeLinks() -> Set<String> {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<WatchedEpisode>()
        let items = (try? context.fetch(descriptor)) ?? []
        return Set(items.map { $0.episodeLink })
    }

    func watchedDates() -> [String: Date] {
        guard let context = modelContext else { return [:] }
        let items = (try? context.fetch(FetchDescriptor<WatchedEpisode>())) ?? []
        return Dictionary(items.map { ($0.episodeLink, $0.watchedAt) }, uniquingKeysWith: { a, b in max(a, b) })
    }

    func isWatched(episodeLink: String) -> Bool {
        guard let context = modelContext else { return false }
        var descriptor = FetchDescriptor<WatchedEpisode>(
            predicate: #Predicate { $0.episodeLink == episodeLink }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func markWatched(episodeLink: String) {
        guard let context = modelContext else { return }
        guard !isWatched(episodeLink: episodeLink) else { return }
        context.insert(WatchedEpisode(episodeLink: episodeLink))
        try? context.save()
        Task { await FirebaseSyncService.shared.uploadWatchedEpisodeStatus(episodeLink: episodeLink) }
    }

    func removeWatched(episodeLink: String) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<WatchedEpisode>(
            predicate: #Predicate { $0.episodeLink == episodeLink }
        )
        if let items = try? context.fetch(descriptor) {
            for item in items { context.delete(item) }
            try? context.save()
        }
        Task { await FirebaseSyncService.shared.deleteWatchedEpisodeStatus(episodeLink: episodeLink) }
    }
}
