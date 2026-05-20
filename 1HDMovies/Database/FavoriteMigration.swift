import Foundation
import SwiftData

@MainActor
enum FavoriteMigration {
    private static let migrationKey = "favorites_migrated_to_swiftdata"

    static func migrateIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let key = "FAVORITE_LIST"
        guard let data = UserDefaults.standard.data(forKey: key),
              let oldFavorites = try? JSONDecoder().decode([MoviesDetailsDataModel].self, from: data),
              !oldFavorites.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        for movie in oldFavorites {
            let favorite = FavoriteMovie.from(movie)
            modelContext.insert(favorite)
        }
        try? modelContext.save()

        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
