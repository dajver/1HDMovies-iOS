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

    /// Progress saves locally every ~10s; throttle the cloud push so we don't write
    /// to Firestore on every tick. Cross-device handoff is still near-real-time.
    private var lastCloudUpload: Date = .distantPast
    private let cloudUploadInterval: TimeInterval = 15

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

        let now = Date()
        let item: PlaybackProgress
        if let existing = fetch(link, in: context) {
            existing.position = position
            existing.duration = duration
            existing.updatedAt = now
            item = existing
        } else {
            item = PlaybackProgress(contentLink: link, position: position, duration: duration)
            context.insert(item)
        }
        try? context.save()

        // Push to the cloud (throttled) so another device resumes from here.
        if now.timeIntervalSince(lastCloudUpload) >= cloudUploadInterval {
            lastCloudUpload = now
            let updatedAt = item.updatedAt
            Task { await FirebaseSyncService.shared.uploadPlaybackProgress(contentLink: link, position: position, duration: duration, updatedAt: updatedAt) }
        }
    }

    func clear(link: String) {
        guard let context = modelContext, let item = fetch(link, in: context) else { return }
        context.delete(item)
        try? context.save()
        Task { await FirebaseSyncService.shared.deletePlaybackProgress(contentLink: link) }
    }

    private func fetch(_ link: String, in context: ModelContext) -> PlaybackProgress? {
        var descriptor = FetchDescriptor<PlaybackProgress>(
            predicate: #Predicate { $0.contentLink == link }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
