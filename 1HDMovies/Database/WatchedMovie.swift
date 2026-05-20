import Foundation
import SwiftData

@Model
final class WatchedMovie {
    @Attribute(.unique) var linkToDetails: String
    var watchedAt: Date

    init(linkToDetails: String) {
        self.linkToDetails = linkToDetails
        self.watchedAt = Date()
    }
}
