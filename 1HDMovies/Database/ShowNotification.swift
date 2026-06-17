import Foundation
import SwiftData

/// A single "new episodes available" notification per favorited TV show.
/// `newEpisodeCount` is the number of new episodes since the user last read it.
@Model
final class ShowNotification {
    @Attribute(.unique) var showLinkToDetails: String
    var showName: String
    var showThumbnail: String
    var newEpisodeCount: Int
    var latestEpisodeNumber: String
    var latestEpisodeName: String
    var detectedAt: Date
    var isRead: Bool

    init(showLinkToDetails: String, showName: String, showThumbnail: String,
         newEpisodeCount: Int, latestEpisodeNumber: String, latestEpisodeName: String) {
        self.showLinkToDetails = showLinkToDetails
        self.showName = showName
        self.showThumbnail = showThumbnail
        self.newEpisodeCount = newEpisodeCount
        self.latestEpisodeNumber = latestEpisodeNumber
        self.latestEpisodeName = latestEpisodeName
        self.detectedAt = Date()
        self.isRead = false
    }
}
