import Foundation
import SwiftData

/// Snapshot of the episode links known for a favorited TV show at the last check.
/// Used to detect episodes added since then.
@Model
final class ShowEpisodeSnapshot {
    @Attribute(.unique) var linkToDetails: String
    var knownEpisodeLinks: [String]
    var lastCheckedAt: Date

    init(linkToDetails: String, knownEpisodeLinks: [String]) {
        self.linkToDetails = linkToDetails
        self.knownEpisodeLinks = knownEpisodeLinks
        self.lastCheckedAt = Date()
    }
}
