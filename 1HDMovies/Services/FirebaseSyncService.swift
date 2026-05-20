import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftData
import Observation
import os

private let log = Logger(subsystem: "com.dajver.one.hd", category: "Sync")

@Observable
@MainActor
final class FirebaseSyncService {
    static let shared = FirebaseSyncService()

    var isSyncing = false
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastSyncDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastSyncDate") }
    }

    private let db = Firestore.firestore()
    private init() {}

    private var uid: String? { AuthenticationService.shared.currentUser?.uid }

    // MARK: - Full Sync

    func syncAll() async {
        guard let uid else {
            log.warning("Sync skipped — no user ID")
            return
        }
        guard !isSyncing else {
            log.warning("Sync skipped — already syncing")
            return
        }
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        log.info("Starting full sync for user: \(uid)")

        do {
            try await uploadNewFavorites(uid: uid)
            try await downloadFavorites(uid: uid)
            try await syncDeletedFavorites(uid: uid)
            log.info("Full sync completed")
        } catch {
            log.error("Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Single Favorite Upload

    func uploadFavorite(_ movie: MoviesDetailsDataModel) async {
        guard let uid else { return }
        do {
            try await uploadSingleFavorite(movie, uid: uid)
            log.info("Uploaded favorite: \(movie.name)")
        } catch {
            log.error("Failed to upload favorite: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete

    func deleteFavorite(_ movie: MoviesDetailsDataModel) async {
        guard let uid else { return }
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("favorites")
                .whereField("linkToDetails", isEqualTo: movie.linkToDetails)
                .getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
            log.info("Deleted favorite from cloud: \(movie.name)")
        } catch {
            log.error("Failed to delete favorite: \(error.localizedDescription)")
        }
    }

    // MARK: - Upload

    private func uploadNewFavorites(uid: String) async throws {
        let localFavorites = FavoriteRepository.shared.fetchAllFavoriteModels()
        let snapshot = try await db.collection("users").document(uid)
            .collection("favorites").getDocuments()

        let cloudLinks = Set(snapshot.documents.compactMap { $0.data()["linkToDetails"] as? String })

        var uploaded = 0
        for favorite in localFavorites {
            if !cloudLinks.contains(favorite.linkToDetails) {
                let movie = favorite.toDetailsModel()
                try await uploadSingleFavorite(movie, uid: uid)
                if favorite.firebaseId == nil {
                    // Find the doc we just created and store its ID
                    let docs = try await db.collection("users").document(uid)
                        .collection("favorites")
                        .whereField("linkToDetails", isEqualTo: favorite.linkToDetails)
                        .getDocuments()
                    favorite.firebaseId = docs.documents.first?.documentID
                }
                uploaded += 1
            } else {
                // Link existing cloud doc to local model
                if favorite.firebaseId == nil {
                    let match = snapshot.documents.first {
                        ($0.data()["linkToDetails"] as? String) == favorite.linkToDetails
                    }
                    favorite.firebaseId = match?.documentID
                }
            }
        }
        try? FavoriteRepository.shared.modelContext?.save()
        log.info("Uploaded \(uploaded) new favorites to cloud")
    }

    private func uploadSingleFavorite(_ movie: MoviesDetailsDataModel, uid: String) async throws {
        let data = favoriteToFirestore(movie)
        try await db.collection("users").document(uid)
            .collection("favorites").addDocument(data: data)
    }

    // MARK: - Download

    private func downloadFavorites(uid: String) async throws {
        let snapshot = try await db.collection("users").document(uid)
            .collection("favorites").getDocuments()

        let localFavorites = FavoriteRepository.shared.fetchAllFavoriteModels()
        let localLinks = Set(localFavorites.map { $0.linkToDetails })

        var downloaded = 0
        for doc in snapshot.documents {
            let data = doc.data()
            guard let linkToDetails = data["linkToDetails"] as? String else { continue }

            if localLinks.contains(linkToDetails) {
                // Link firebaseId if missing
                if let local = localFavorites.first(where: { $0.linkToDetails == linkToDetails }),
                   local.firebaseId == nil {
                    local.firebaseId = doc.documentID
                }
                continue
            }

            let movie = firestoreToFavorite(data)
            FavoriteRepository.shared.addWithoutSync(movie)

            // Set firebaseId on the newly inserted model
            let link = movie.linkToDetails
            var descriptor = FetchDescriptor<FavoriteMovie>(
                predicate: #Predicate { $0.linkToDetails == link }
            )
            descriptor.fetchLimit = 1
            if let inserted = try? FavoriteRepository.shared.modelContext?.fetch(descriptor).first {
                inserted.firebaseId = doc.documentID
            }

            downloaded += 1
        }
        try? FavoriteRepository.shared.modelContext?.save()
        log.info("Downloaded \(downloaded) favorites from cloud")
    }

    // MARK: - Delete Sync

    private func syncDeletedFavorites(uid: String) async throws {
        let snapshot = try await db.collection("users").document(uid)
            .collection("favorites").getDocuments()

        let localFavorites = FavoriteRepository.shared.fetchAllFavoriteModels()
        let localLinks = Set(localFavorites.map { $0.linkToDetails })

        for doc in snapshot.documents {
            let data = doc.data()
            guard let linkToDetails = data["linkToDetails"] as? String else { continue }
            if !localLinks.contains(linkToDetails) {
                try await doc.reference.delete()
                log.info("Deleted orphaned cloud favorite: \(linkToDetails)")
            }
        }
    }

    // MARK: - Serialization

    private func favoriteToFirestore(_ movie: MoviesDetailsDataModel) -> [String: Any] {
        var data: [String: Any] = [
            "name": movie.name,
            "thumbnail": movie.thumbnail,
            "linkToWatch": movie.linkToWatch,
            "linkToDetails": movie.linkToDetails,
            "watchMovieLinkWithEpisodeId": movie.watchMovieLinkWithEpisodeId,
            "type": movie.type.rawValue,
            "description": movie.description,
            "quality": movie.quality,
            "cast": movie.cast,
            "genre": movie.genre,
            "duration": movie.duration,
            "country": movie.country,
            "imdb": movie.imdb,
            "release": movie.release,
            "production": movie.production,
            "addedAt": Timestamp(date: movie.addedAt ?? Date())
        ]

        if let seasons = movie.seasonsList {
            let seasonsData: [[String: Any]] = seasons.map { season in
                let episodes: [[String: Any]] = season.episodes.map { ep in
                    [
                        "episodeNumber": ep.episodeNumber,
                        "episodeName": ep.episodeName,
                        "link": ep.link
                    ]
                }
                return [
                    "seasonId": season.seasonId,
                    "seasonNumber": season.seasonNumber,
                    "episodes": episodes
                ]
            }
            data["seasonsList"] = seasonsData
        }

        return data
    }

    private func firestoreToFavorite(_ data: [String: Any]) -> MoviesDetailsDataModel {
        let typeString = data["type"] as? String ?? "Movie"
        let type = MovieType(rawValue: typeString) ?? .movie

        var movie = MoviesDetailsDataModel(
            name: data["name"] as? String ?? "",
            thumbnail: data["thumbnail"] as? String ?? "",
            linkToWatch: data["linkToWatch"] as? String ?? "",
            linkToDetails: data["linkToDetails"] as? String ?? "",
            watchMovieLinkWithEpisodeId: data["watchMovieLinkWithEpisodeId"] as? String ?? "",
            type: type,
            description: data["description"] as? String ?? "",
            quality: data["quality"] as? String ?? "",
            cast: data["cast"] as? String ?? "",
            genre: data["genre"] as? String ?? "",
            duration: data["duration"] as? String ?? "",
            country: data["country"] as? String ?? "",
            imdb: data["imdb"] as? String ?? "",
            release: data["release"] as? String ?? "",
            production: data["production"] as? String ?? ""
        )

        if let seasonsData = data["seasonsList"] as? [[String: Any]] {
            movie.seasonsList = seasonsData.map { seasonData in
                let episodes = (seasonData["episodes"] as? [[String: Any]] ?? []).map { epData in
                    MovieEpisodesDataModel(
                        episodeNumber: epData["episodeNumber"] as? String ?? "",
                        episodeName: epData["episodeName"] as? String ?? "",
                        link: epData["link"] as? String ?? ""
                    )
                }
                return MovieSeasonDataModel(
                    seasonId: seasonData["seasonId"] as? String ?? "",
                    seasonNumber: seasonData["seasonNumber"] as? String ?? "",
                    episodes: episodes
                )
            }
        }

        if let addedAt = data["addedAt"] as? Timestamp {
            movie.addedAt = addedAt.dateValue()
        }

        return movie
    }
}
