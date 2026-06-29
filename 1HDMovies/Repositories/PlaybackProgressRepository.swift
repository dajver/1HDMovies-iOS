import Foundation
import SwiftData

@MainActor
class PlaybackProgressRepository {
    static let shared = PlaybackProgressRepository()

    var modelContext: ModelContext?

    /// Don't resume from the very start (treat as "not started") or from the tail
    /// end (treat as "finished"); both should just play from the beginning.
    private let minResumeSeconds: Double = 5
    private let endTailSeconds: Double = 15

    /// Saved resume position for a content link, or nil if there's nothing useful
    /// to resume (no record, too early, or effectively finished).
    func position(for link: String) -> Double? {
        guard let context = modelContext, let item = fetch(link, in: context) else { return nil }
        guard item.position >= minResumeSeconds else { return nil }
        if item.duration > 0, item.position >= item.duration - endTailSeconds { return nil }
        return item.position
    }

    /// Upserts the resume point. Clears it once playback reaches the end so the
    /// next open starts fresh instead of resuming at the credits.
    func save(link: String, position: Double, duration: Double) {
        guard let context = modelContext, position.isFinite, position >= 0 else { return }

        if duration > 0, position >= duration - endTailSeconds {
            clear(link: link)
            return
        }

        if let item = fetch(link, in: context) {
            item.position = position
            item.duration = duration
            item.updatedAt = Date()
        } else {
            context.insert(PlaybackProgress(contentLink: link, position: position, duration: duration))
        }
        try? context.save()
    }

    func clear(link: String) {
        guard let context = modelContext, let item = fetch(link, in: context) else { return }
        context.delete(item)
        try? context.save()
    }

    private func fetch(_ link: String, in context: ModelContext) -> PlaybackProgress? {
        var descriptor = FetchDescriptor<PlaybackProgress>(
            predicate: #Predicate { $0.contentLink == link }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
