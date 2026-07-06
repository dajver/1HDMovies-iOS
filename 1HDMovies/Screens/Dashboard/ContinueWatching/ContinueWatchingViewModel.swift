import Foundation
import os

private let log = Logger(subsystem: "com.dajver.one.hd", category: "ContinueWatching")

struct ContinueWatchingItem: Identifiable {
    /// A row can be a TV show (resume/next episode) or a partially-watched movie.
    enum Kind {
        case show(episodes: [MovieEpisodesDataModel], targetIndex: Int, isResume: Bool)
        case movie(url: String)
    }

    let id: String          // show linkToDetails, or movie watch URL
    let title: String
    let thumbnail: String
    let kind: Kind
    let lastWatchedAt: Date  // for ordering the row

    /// Episode being proposed (nil for movies).
    var episode: MovieEpisodesDataModel? {
        if case let .show(episodes, targetIndex, _) = kind { return episodes[targetIndex] }
        return nil
    }

    /// Episodes remaining including the proposed one (0 for movies).
    var remaining: Int {
        if case let .show(episodes, targetIndex, _) = kind { return episodes.count - targetIndex }
        return 0
    }

    /// Whether we're resuming a partially-watched item vs. starting the next one.
    var isResume: Bool {
        switch kind {
        case let .show(_, _, isResume): return isResume
        case .movie: return true
        }
    }
}

@Observable
class ContinueWatchingViewModel {
    var items: [ContinueWatchingItem] = []

    @MainActor
    func refresh() {
        let watched = WatchedEpisodeRepository.shared.allWatchedEpisodeLinks()
        let dates = WatchedEpisodeRepository.shared.watchedDates()
        let shows = FavoriteRepository.shared.fetchAllFavoriteModels().filter { $0.movieType == .tvShow }
        let progress = PlaybackProgressRepository.shared

        var result: [ContinueWatchingItem] = []
        for show in shows {
            let episodes = (show.seasonsList ?? []).flatMap { $0.episodes }
            guard !episodes.isEmpty else { continue }

            // Furthest-progress watched episode (not the most recent by time) so we
            // never propose earlier seasons the user skipped past.
            var maxWatchedIndex = -1
            for (index, episode) in episodes.enumerated() where watched.contains(episode.link) {
                maxWatchedIndex = index
            }
            guard maxWatchedIndex >= 0 else { continue }            // not started — excluded

            // If the furthest-watched episode was abandoned mid-way (still has a
            // resumable position), keep proposing THAT episode so the user resumes it
            // instead of jumping to the next one. Otherwise advance to the next episode.
            let targetIndex: Int
            if progress.position(for: episodes[maxWatchedIndex].link) != nil {
                targetIndex = maxWatchedIndex
            } else {
                targetIndex = maxWatchedIndex + 1
                guard targetIndex < episodes.count else { continue }   // caught up / finished
            }

            let isResume = progress.position(for: episodes[targetIndex].link) != nil
            let lastWatchedAt = dates[episodes[maxWatchedIndex].link] ?? .distantPast
            result.append(ContinueWatchingItem(
                id: show.linkToDetails,
                title: show.name,
                thumbnail: show.thumbnail,
                kind: .show(episodes: episodes, targetIndex: targetIndex, isResume: isResume),
                lastWatchedAt: lastWatchedAt
            ))
        }

        // Partially-watched movies (any in-progress position, favorited or not).
        for record in progress.inProgressMovies() {
            result.append(ContinueWatchingItem(
                id: record.contentLink,
                title: record.title,
                thumbnail: record.thumbnail,
                kind: .movie(url: record.contentLink),
                lastWatchedAt: record.updatedAt
            ))
        }

        log.info("ContinueWatching: \(shows.count) favorited TV shows -> \(result.count) items")
        items = result.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
    }
}
