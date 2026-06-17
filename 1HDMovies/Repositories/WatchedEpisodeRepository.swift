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
}
