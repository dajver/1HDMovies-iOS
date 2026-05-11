import Foundation

@Observable
class FavoriteViewModel {
    var favorites: [MoviesDetailsDataModel] = []

    func fetchFavorites() {
        favorites = FavoriteRepository.shared.fetchAllFavorites()
    }
}
