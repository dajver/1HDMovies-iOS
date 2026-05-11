import Foundation
import SwiftSoup

class YouMayAlsoLikeRepository {
    static let shared = YouMayAlsoLikeRepository()

    func fetchYouMayAlsoLike(url: String) async throws -> [MoviesDataModel] {
        let linkToMovie = url.hasPrefix("https://1hd") ? url : "\(Config.baseURL)/\(url)"
        let html = try await HttpClient.shared.get(linkToMovie)
        let doc = try SwiftSoup.parse(html)
        let moviesElements = try doc.select("div.swiper-slide").select("div.item-film")
        let filmVisualInformation = try moviesElements.select("div.film-thumbnail").select("img.film-thumbnail-img")
        let filmTextInformation = try moviesElements.select("div.film-detail")
        let filmReleaseInformation = try moviesElements.select("div.film-info")
        let qualities = try moviesElements.select("div.film-thumbnail").select("div.quality")
        let thumbnails = try filmVisualInformation.eachAttr("src")
        let names = try filmVisualInformation.eachAttr("alt")
        let links = try filmTextInformation.select("h3.film-name").select("a").eachAttr("href")

        let dateInfoElements = try filmReleaseInformation.select("span.item")
        var dateInfo: [String] = []
        for element in dateInfoElements.array() {
            for textNode in element.textNodes() {
                let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    dateInfo.append(text)
                }
            }
        }

        var typeAndYear: [String] = []
        var i = 0
        while i < dateInfo.count - 1 {
            let type = dateInfo[i]
            let year = dateInfo[i + 1]
            typeAndYear.append("\(type),\(year)")
            i += 2
        }

        var movies: [MoviesDataModel] = []
        for index in 0..<thumbnails.count {
            guard index < names.count, index < links.count else { break }
            let name = names[index]
            let thumbnail = thumbnails[index]
            let link = links[index]
            let type: MovieType = (index < typeAndYear.count && typeAndYear[index].split(separator: ",").first == "Movie") ? .movie : .tvShow
            let quality = index < qualities.count ? (try? qualities.element(at: index).text()) ?? "" : ""
            let releaseYear = index < typeAndYear.count ? String(typeAndYear[index].split(separator: ",").last ?? "") : ""
            movies.append(MoviesDataModel(name: name, thumbnail: thumbnail, link: link, type: type, quality: quality, other: releaseYear))
        }
        return movies
    }
}
