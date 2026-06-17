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

    /// Refresh an already-favorited show's stored metadata (name, thumbnail) and
    /// episode list from fresh details. Fixes favorites saved before parsing fixes
    /// (e.g. empty name / stale episode-link format) and reflects newly-added
    /// episodes. No-op if the show isn't favorited or nothing changed.
    func refreshFavoriteIfNeeded(_ movie: MoviesDetailsDataModel) {
        guard let context = modelContext else { return }
        let link = movie.linkToDetails
        var descriptor = FetchDescriptor<FavoriteMovie>(
            predicate: #Predicate { $0.linkToDetails == link }
        )
        descriptor.fetchLimit = 1
        guard let favorite = try? context.fetch(descriptor).first else { return }

        var changed = false
        if !movie.name.isEmpty && favorite.name != movie.name {
            favorite.name = movie.name
            changed = true
        }
        if !movie.thumbnail.isEmpty && favorite.thumbnail != movie.thumbnail {
            favorite.thumbnail = movie.thumbnail
            changed = true
        }
        if let seasons = movie.seasonsList, !seasons.isEmpty {
            let newLinks = seasons.flatMap { $0.episodes.map { $0.link } }
            let oldLinks = favorite.seasonsList?.flatMap { $0.episodes.map { $0.link } } ?? []
            if newLinks != oldLinks {
                favorite.seasonsJson = try? JSONEncoder().encode(seasons)
                changed = true
            }
        }
        if changed { try? context.save() }
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
