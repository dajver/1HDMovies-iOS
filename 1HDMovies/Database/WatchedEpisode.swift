import Foundation
import SwiftData

@Model
final class WatchedEpisode {
    @Attribute(.unique) var episodeLink: String
    var watchedAt: Date

    init(episodeLink: String) {
        self.episodeLink = episodeLink
        self.watchedAt = Date()
    }
}
