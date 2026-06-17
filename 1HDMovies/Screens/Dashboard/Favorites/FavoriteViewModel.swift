import Foundation

@Observable
class FavoriteViewModel {
    var favorites: [MoviesDetailsDataModel] = []

    @MainActor
    func fetchFavorites() {
        let watched = WatchedRepository.shared.allWatchedLinks()
        favorites = FavoriteRepository.shared.fetchAllFavorites()
            .filter { !watched.contains($0.linkToDetails) }
    }
}
