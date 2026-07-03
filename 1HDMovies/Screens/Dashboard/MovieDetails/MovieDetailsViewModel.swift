import Foundation

@Observable
class MovieDetailsViewModel {
    var movieDetails: MoviesDetailsDataModel?
    var youMayAlsoLike: [MoviesDataModel] = []
    var isLoading = true
    var selectedSeason: MovieSeasonDataModel?
    var selectedEpisodes: [MovieEpisodesDataModel] = []
    var watchedEpisodeLinks: Set<String> = []

    func fetchDetails(url: String) async {
        do {
            let details = try await MovieDetailsRepository.shared.fetchDetails(url: url)
            await MainActor.run {
                self.movieDetails = details
                if let seasons = details.seasonsList, !seasons.isEmpty {
                    let watched = WatchedEpisodeRepository.shared.allWatchedEpisodeLinks()
                    self.watchedEpisodeLinks = watched
                    let season = self.currentWatchingSeason(seasons: seasons, watched: watched)
                    self.selectedSeason = season
                    self.selectedEpisodes = season.episodes
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }

    func fetchYouMayAlsoLike(url: String) async {
        do {
            let result = try await YouMayAlsoLikeRepository.shared.fetchYouMayAlsoLike(url: url)
            await MainActor.run { self.youMayAlsoLike = result }
        } catch {}
    }

    func selectSeason(_ season: MovieSeasonDataModel) {
        selectedSeason = season
        selectedEpisodes = season.episodes
    }

    /// The season the user should land on when opening a show.
    /// If the show has watched episodes it returns the season the user is
    /// currently watching — the one holding their next unfinished episodes.
    /// If nothing is watched it returns the first season, so a fresh show
    /// opens at the beginning rather than the newest season.
    private func currentWatchingSeason(seasons: [MovieSeasonDataModel], watched: Set<String>) -> MovieSeasonDataModel {
        // Furthest (latest-in-order) season that contains a watched episode.
        guard let furthestIndex = seasons.lastIndex(where: { season in
            season.episodes.contains { watched.contains($0.link) }
        }) else {
            // Nothing watched → start from the first season.
            return seasons.first!
        }

        let furthestSeason = seasons[furthestIndex]
        // Still has unwatched episodes → that's where they're watching.
        if furthestSeason.episodes.contains(where: { !watched.contains($0.link) }) {
            return furthestSeason
        }
        // Season fully watched → advance to the next season if there is one.
        let nextIndex = furthestIndex + 1
        return nextIndex < seasons.count ? seasons[nextIndex] : furthestSeason
    }

    @MainActor
    func refreshWatchedEpisodes() {
        watchedEpisodeLinks = WatchedEpisodeRepository.shared.allWatchedEpisodeLinks()
    }

    func toggleFavorite() {
        guard let movie = movieDetails else { return }
        FavoriteRepository.shared.favorite(movie)
    }

    func isFavorite() -> Bool {
        guard let movie = movieDetails else { return false }
        return FavoriteRepository.shared.hasMovie(movie)
    }

    func toggleWatched() {
        guard let movie = movieDetails else { return }
        WatchedRepository.shared.toggleWatched(linkToDetails: movie.linkToDetails)
    }

    func isWatched() -> Bool {
        guard let movie = movieDetails else { return false }
        return WatchedRepository.shared.isWatched(linkToDetails: movie.linkToDetails)
    }
}
