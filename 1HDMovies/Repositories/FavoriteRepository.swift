import Foundation
import SwiftData

@MainActor
class FavoriteRepository {
    static let shared = FavoriteRepository()

    var modelContext: ModelContext?

    func fetchAllFavorites() -> [MoviesDetailsDataModel] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<FavoriteMovie>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        let favorites = (try? context.fetch(descriptor)) ?? []
        return favorites.map { $0.toDetailsModel() }
    }

    func fetchAllFavoriteModels() -> [FavoriteMovie] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<FavoriteMovie>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func favorite(_ movie: MoviesDetailsDataModel) {
        if hasMovie(movie) {
            remove(movie)
            Task {
                await FirebaseSyncService.shared.deleteFavorite(movie)
            }
        } else {
            save(movie)
            Task {
                await FirebaseSyncService.shared.uploadFavorite(movie)
            }
        }
    }

    func hasMovie(_ movie: MoviesDetailsDataModel) -> Bool {
        guard let context = modelContext else { return false }
        let link = movie.linkToDetails
        var descriptor = FetchDescriptor<FavoriteMovie>(
            predicate: #Predicate { $0.linkToDetails == link }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func addWithoutSync(_ movie: MoviesDetailsDataModel) {
        guard let context = modelContext else { return }
        let link = movie.linkToDetails
        var check = FetchDescriptor<FavoriteMovie>(
            predicate: #Predicate { $0.linkToDetails == link }
        )
        check.fetchLimit = 1
        if ((try? context.fetchCount(check)) ?? 0) > 0 { return }

        let favorite = FavoriteMovie.from(movie)
        context.insert(favorite)
        try? context.save()
    }

    private func save(_ movie: MoviesDetailsDataModel) {
        guard let context = modelContext else { return }
        let favorite = FavoriteMovie.from(movie)
        context.insert(favorite)
        try? context.save()
    }

    private func remove(_ movie: MoviesDetailsDataModel) {
        guard let context = modelContext else { return }
        let link = movie.linkToDetails
        let descriptor = FetchDescriptor<FavoriteMovie>(
            predicate: #Predicate { $0.linkToDetails == link }
        )
        if let favorites = try? context.fetch(descriptor) {
            for fav in favorites {
                context.delete(fav)
            }
            try? context.save()
        }
    }
}
