import Foundation
import SwiftData

@Model
final class FavoriteMovie {
    @Attribute(.unique) var linkToDetails: String
    var name: String
    var thumbnail: String
    var linkToWatch: String
    var watchMovieLinkWithEpisodeId: String
    var type: String
    var movieDescription: String
    var quality: String
    var cast: String
    var genre: String
    var duration: String
    var country: String
    var imdb: String
    var release: String
    var production: String
    var seasonsJson: Data?
    var addedAt: Date
    var firebaseId: String?

    init(name: String, thumbnail: String, linkToWatch: String, linkToDetails: String,
         watchMovieLinkWithEpisodeId: String, type: MovieType, description: String,
         quality: String, cast: String, genre: String, duration: String,
         country: String, imdb: String, release: String, production: String,
         seasonsList: [MovieSeasonDataModel]? = nil, addedAt: Date = Date()) {
        self.name = name
        self.thumbnail = thumbnail
        self.linkToWatch = linkToWatch
        self.linkToDetails = linkToDetails
        self.watchMovieLinkWithEpisodeId = watchMovieLinkWithEpisodeId
        self.type = type.rawValue
        self.movieDescription = description
        self.quality = quality
        self.cast = cast
        self.genre = genre
        self.duration = duration
        self.country = country
        self.imdb = imdb
        self.release = release
        self.production = production
        self.addedAt = addedAt

        if let seasons = seasonsList {
            self.seasonsJson = try? JSONEncoder().encode(seasons)
        }
    }

    var movieType: MovieType {
        MovieType(rawValue: type) ?? .movie
    }

    var seasonsList: [MovieSeasonDataModel]? {
        guard let data = seasonsJson else { return nil }
        return try? JSONDecoder().decode([MovieSeasonDataModel].self, from: data)
    }

    func toDetailsModel() -> MoviesDetailsDataModel {
        var model = MoviesDetailsDataModel(
            name: name,
            thumbnail: thumbnail,
            linkToWatch: linkToWatch,
            linkToDetails: linkToDetails,
            watchMovieLinkWithEpisodeId: watchMovieLinkWithEpisodeId,
            type: movieType,
            description: movieDescription,
            quality: quality,
            cast: cast,
            genre: genre,
            duration: duration,
            country: country,
            imdb: imdb,
            release: release,
            production: production,
            seasonsList: seasonsList
        )
        model.addedAt = addedAt
        return model
    }

    static func from(_ movie: MoviesDetailsDataModel) -> FavoriteMovie {
        FavoriteMovie(
            name: movie.name,
            thumbnail: movie.thumbnail,
            linkToWatch: movie.linkToWatch,
            linkToDetails: movie.linkToDetails,
            watchMovieLinkWithEpisodeId: movie.watchMovieLinkWithEpisodeId,
            type: movie.type,
            description: movie.description,
            quality: movie.quality,
            cast: movie.cast,
            genre: movie.genre,
            duration: movie.duration,
            country: movie.country,
            imdb: movie.imdb,
            release: movie.release,
            production: movie.production,
            seasonsList: movie.seasonsList,
            addedAt: movie.addedAt ?? Date()
        )
    }
}
