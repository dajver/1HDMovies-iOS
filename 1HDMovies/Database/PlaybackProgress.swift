import Foundation
import SwiftData

/// Resume point for a movie or a single TV episode. Keyed by the content's stable
/// watch link (episode link for shows, watch URL for movies) so it survives the
/// per-session, sniffed `.m3u8` stream URL changing.
@Model
final class PlaybackProgress {
    @Attribute(.unique) var contentLink: String
    var position: Double      // seconds watched into the item
    var duration: Double      // total length when last saved (0 if unknown)
    var updatedAt: Date

    // Display metadata so a movie can be shown in "Continue Watching" without being
    // favorited (episodes get theirs from the favorited show instead). Empty for
    // records created before this was added / for episodes.
    var title: String = ""
    var thumbnail: String = ""
    var contentType: String = ""   // MovieType raw value ("Movie" / "TV Show"), "" if unknown

    init(contentLink: String, position: Double, duration: Double,
         title: String = "", thumbnail: String = "", contentType: String = "") {
        self.contentLink = contentLink
        self.position = position
        self.duration = duration
        self.updatedAt = Date()
        self.title = title
        self.thumbnail = thumbnail
        self.contentType = contentType
    }
}
