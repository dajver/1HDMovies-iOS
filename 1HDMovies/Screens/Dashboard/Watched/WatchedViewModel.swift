import Foundation

@Observable
class WatchedViewModel {
    var watched: [MoviesDetailsDataModel] = []

    @MainActor
    func fetchWatched() {
        let watchedLinks = WatchedRepository.shared.allWatchedLinks()
        watched = FavoriteRepository.shared.fetchAllFavorites()
            .filter { watchedLinks.contains($0.linkToDetails) }
    }
}
