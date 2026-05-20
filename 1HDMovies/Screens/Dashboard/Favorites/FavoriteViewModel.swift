import Foundation

@Observable
class FavoriteViewModel {
    var favorites: [MoviesDetailsDataModel] = []

    @MainActor
    func fetchFavorites() {
        favorites = FavoriteRepository.shared.fetchAllFavorites()
    }
}
