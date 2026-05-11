import Foundation

struct FilterOptions {
    var type: Set<FilterType> = []
    var genre: String = ""
    var country: String = ""
    var year: String = ""
    var sort: FilterSort = .defaultSort

    var queryString: String {
        var params: [String] = []
        if !type.isEmpty {
            let typeValues = type.map { $0.rawValue }.sorted().joined(separator: ",")
            params.append("type=\(typeValues)")
        }
        if !genre.isEmpty {
            let encoded = genre.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? genre
            params.append("genre=\(encoded)")
        }
        if !country.isEmpty {
            let encoded = country.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? country
            params.append("country=\(encoded)")
        }
        if !year.isEmpty {
            params.append("year=\(year)")
        }
        params.append("sort=\(sort.rawValue)")
        return params.joined(separator: "&")
    }

    var isEmpty: Bool {
        type.isEmpty && genre.isEmpty && country.isEmpty && year.isEmpty && sort == .defaultSort
    }
}

enum FilterType: String, CaseIterable, Hashable {
    case movie = "2"
    case tvSeries = "1"

    var displayName: String {
        switch self {
        case .movie: return "Movie"
        case .tvSeries: return "TV Series"
        }
    }
}

enum FilterSort: String, CaseIterable {
    case defaultSort = "default"
    case lastUpdated = "last_updated"

    var displayName: String {
        switch self {
        case .defaultSort: return "Default"
        case .lastUpdated: return "Last Updated"
        }
    }
}

enum FilterData {
    static let genres = [
        "All", "Drama", "Comedy", "Thriller", "Action", "Romance", "Horror", "Crime",
        "Documentary", "Adventure", "Mystery", "Fantasy", "Family", "Science Fiction",
        "TV Movie", "Animation", "History", "Music", "War", "Western"
    ]

    static let countries = [
        "United States of America", "United Kingdom", "France", "Canada", "Germany",
        "Japan", "Italy", "India", "Spain", "Australia", "Hong Kong", "South Korea",
        "China", "Belgium", "Sweden", "Mexico", "Denmark", "Ireland", "Poland", "Russia",
        "Netherlands", "Brazil", "Norway", "Argentina", "South Africa", "Finland",
        "Switzerland", "New Zealand", "Austria", "Thailand", "Turkey", "Hungary",
        "Czech Republic", "Taiwan", "Israel", "Romania", "Philippines", "Portugal",
        "Greece", "Chile", "Indonesia", "Iceland", "Colombia", "Ukraine", "Singapore",
        "Serbia", "Nigeria", "Malaysia", "Iran"
    ]

    static let years: [String] = {
        var result = [""]
        for year in stride(from: 2025, through: 1970, by: -1) {
            result.append(String(year))
        }
        return result
    }()
}
