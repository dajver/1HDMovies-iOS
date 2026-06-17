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
                    let lastSeason = seasons.last!
                    self.selectedSeason = lastSeason
                    self.selectedEpisodes = lastSeason.episodes
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
