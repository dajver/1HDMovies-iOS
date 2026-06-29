import Foundation

enum MovieType: String, Codable {
    case movie = "Movie"
    case tvShow = "TV Show"
}

struct MoviesDataModel: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let thumbnail: String
    let link: String
    let type: MovieType
    let quality: String
    let other: String
    var genre: GenresEnum? = nil
    var isSelected: Bool = false

    static func == (lhs: MoviesDataModel, rhs: MoviesDataModel) -> Bool {
        lhs.link == rhs.link
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(link)
    }
}

struct MostPopularMoviesDataModel: Identifiable {
    let id = UUID()
    let name: String
    let thumbnail: String
    let link: String
    let quality: String
    let description: String
}

struct MoviesDetailsDataModel: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let thumbnail: String
    let linkToWatch: String
    let linkToDetails: String
    let watchMovieLinkWithEpisodeId: String
    let type: MovieType
    let description: String
    let quality: String
    let cast: String
    let genre: String
    let duration: String
    let country: String
    let imdb: String
    let release: String
    let production: String
    var seasonsList: [MovieSeasonDataModel]?
    var addedAt: Date?

    init(name: String, thumbnail: String, linkToWatch: String, linkToDetails: String, watchMovieLinkWithEpisodeId: String, type: MovieType, description: String, quality: String, cast: String, genre: String, duration: String, country: String, imdb: String, release: String, production: String, seasonsList: [MovieSeasonDataModel]? = nil) {
        self.id = UUID()
        self.name = name
        self.thumbnail = thumbnail
        self.linkToWatch = linkToWatch
        self.linkToDetails = linkToDetails
        self.watchMovieLinkWithEpisodeId = watchMovieLinkWithEpisodeId
        self.type = type
        self.description = description
        self.quality = quality
        self.cast = cast
        self.genre = genre
        self.duration = duration
        self.country = country
        self.imdb = imdb
        self.release = release
        self.production = production
        self.seasonsList = seasonsList
    }

    static func == (lhs: MoviesDetailsDataModel, rhs: MoviesDetailsDataModel) -> Bool {
        lhs.linkToDetails == rhs.linkToDetails
    }
}

struct MovieSeasonDataModel: Identifiable, Codable, Hashable {
    let id = UUID()
    let seasonId: String
    let seasonNumber: String
    var episodes: [MovieEpisodesDataModel]
    var isSelected: Bool = false

    enum CodingKeys: String, CodingKey {
        case seasonId, seasonNumber, episodes, isSelected
    }

    init(seasonId: String, seasonNumber: String, episodes: [MovieEpisodesDataModel]) {
        self.seasonId = seasonId
        self.seasonNumber = seasonNumber
        self.episodes = episodes
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(seasonId)
    }

    static func == (lhs: MovieSeasonDataModel, rhs: MovieSeasonDataModel) -> Bool {
        lhs.seasonId == rhs.seasonId
    }
}

struct MovieEpisodesDataModel: Identifiable, Codable, Hashable {
    let id = UUID()
    let episodeNumber: String
    let episodeName: String
    let link: String
    var isSelected: Bool = false

    enum CodingKeys: String, CodingKey {
        case episodeNumber, episodeName, link, isSelected
    }

    init(episodeNumber: String, episodeName: String, link: String) {
        self.episodeNumber = episodeNumber
        self.episodeName = episodeName
        self.link = link
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(link)
    }

    static func == (lhs: MovieEpisodesDataModel, rhs: MovieEpisodesDataModel) -> Bool {
        lhs.link == rhs.link
    }
}

enum GenresEnum: String, CaseIterable {
    case action = "Action"
    case comedy = "Comedy"
    case drama = "Drama"
    case fantasy = "Fantasy"
    case horror = "Horror"
    case mystery = "Mystery"
    case animation = "Animation"
    case topIMDB = "Top IMDB"

    var path: String {
        switch self {
        case .action: return "/genre/action"
        case .comedy: return "/genre/comedy"
        case .drama: return "/genre/drama"
        case .fantasy: return "/genre/fantasy"
        case .horror: return "/genre/horror"
        case .mystery: return "/genre/mystery"
        case .animation: return "/genre/animation"
        case .topIMDB: return "/top-imdb"
        }
    }

    var url: String { "\(Config.baseURL)\(path)" }
}
