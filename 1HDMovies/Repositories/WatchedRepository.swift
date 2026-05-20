import Foundation
import SwiftData

@MainActor
class WatchedRepository {
    static let shared = WatchedRepository()

    var modelContext: ModelContext?

    func isWatched(linkToDetails: String) -> Bool {
        guard let context = modelContext else { return false }
        var descriptor = FetchDescriptor<WatchedMovie>(
            predicate: #Predicate { $0.linkToDetails == linkToDetails }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func toggleWatched(linkToDetails: String) {
        if isWatched(linkToDetails: linkToDetails) {
            removeWatched(linkToDetails: linkToDetails)
            Task { await FirebaseSyncService.shared.deleteWatchedStatus(linkToDetails: linkToDetails) }
        } else {
            markWatched(linkToDetails: linkToDetails)
            Task { await FirebaseSyncService.shared.uploadWatchedStatus(linkToDetails: linkToDetails) }
        }
    }

    func markWatched(linkToDetails: String) {
        guard let context = modelContext else { return }
        guard !isWatched(linkToDetails: linkToDetails) else { return }
        context.insert(WatchedMovie(linkToDetails: linkToDetails))
        try? context.save()
    }

    func removeWatched(linkToDetails: String) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<WatchedMovie>(
            predicate: #Predicate { $0.linkToDetails == linkToDetails }
        )
        if let items = try? context.fetch(descriptor) {
            for item in items { context.delete(item) }
            try? context.save()
        }
    }
}
