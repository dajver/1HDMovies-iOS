import Foundation

class FavoriteRepository {
    static let shared = FavoriteRepository()

    private let key = "FAVORITE_LIST"

    func fetchAllFavorites() -> [MoviesDetailsDataModel] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let favorites = try? JSONDecoder().decode([MoviesDetailsDataModel].self, from: data) else {
            return []
        }
        return favorites.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
    }

    func favorite(_ movie: MoviesDetailsDataModel) {
        if hasMovie(movie) {
            remove(movie)
        } else {
            save(movie)
        }
    }

    func hasMovie(_ movie: MoviesDetailsDataModel) -> Bool {
        let favorites = fetchAllFavorites()
        return favorites.contains(where: { $0.linkToDetails == movie.linkToDetails })
    }

    private func save(_ movie: MoviesDetailsDataModel) {
        var favorites = fetchAllFavorites()
        var movieToSave = movie
        movieToSave.addedAt = Date()
        favorites.append(movieToSave)
        saveToDisk(favorites)
    }

    private func remove(_ movie: MoviesDetailsDataModel) {
        var favorites = fetchAllFavorites()
        favorites.removeAll { $0.linkToDetails == movie.linkToDetails }
        saveToDisk(favorites)
    }

    private func saveToDisk(_ favorites: [MoviesDetailsDataModel]) {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
