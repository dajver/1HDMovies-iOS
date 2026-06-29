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
    // Individual, clickable tags parsed from the details page (each links to a listing page:
    // genre, actor, country, production company, year). Not persisted (omitted from CodingKeys)
    // — favorites keep the plain `genre`/`cast`/… strings instead.
    var genres: [TagRef] = []
    var casts: [TagRef] = []
    var countries: [TagRef] = []
    var productions: [TagRef] = []
    var years: [TagRef] = []
    var seasonsList: [MovieSeasonDataModel]?
    var addedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, thumbnail, linkToWatch, linkToDetails, watchMovieLinkWithEpisodeId
        case type, description, quality, cast, genre, duration, country, imdb, release
        case production, seasonsList, addedAt
    }

    init(name: String, thumbnail: String, linkToWatch: String, linkToDetails: String, watchMovieLinkWithEpisodeId: String, type: MovieType, description: String, quality: String, cast: String, genre: String, duration: String, country: String, imdb: String, release: String, production: String, genres: [TagRef] = [], casts: [TagRef] = [], countries: [TagRef] = [], productions: [TagRef] = [], years: [TagRef] = [], seasonsList: [MovieSeasonDataModel]? = nil) {
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
        self.genres = genres
        self.casts = casts
        self.countries = countries
        self.productions = productions
        self.years = years
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

    var ref: TagRef { TagRef(name: rawValue, url: url) }
}

// A generic, clickable reference to a listing page — used for genres, cast members,
// countries, production companies and years parsed off a details page. These values
// are arbitrary (not limited to the fixed `GenresEnum`), so navigation carries a
// display name + absolute URL and is rendered by the shared listing screen.
struct TagRef: Hashable, Codable {
    let name: String
    let url: String
}
