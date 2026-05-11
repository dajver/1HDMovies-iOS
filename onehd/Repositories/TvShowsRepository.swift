import Foundation
import SwiftSoup

class TvShowsRepository {
    static let shared = TvShowsRepository()

    func fetchTvShows(page: Int) async throws -> [MoviesDataModel] {
        let html = try await HttpClient.shared.get("\(Config.baseURL)/tv-series/page/\(page)")
        let doc = try SwiftSoup.parse(html)
        let moviesElements = try doc.select("div.container").select("div.film-list").select("div.item-film")
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
        let episodes = dateInfo.filter { $0.contains("SS") }

        var movies: [MoviesDataModel] = []
        for index in 0..<thumbnails.count {
            guard index < names.count, index < links.count else { break }
            let name = names[index]
            let thumbnail = thumbnails[index]
            let link = links[index]
            let quality = index < qualities.count ? (try? qualities.element(at: index).text()) ?? "" : ""
            let episode = index < episodes.count ? episodes[index] : ""
            movies.append(MoviesDataModel(name: name, thumbnail: thumbnail, link: link, type: .tvShow, quality: quality, other: episode))
        }
        return movies
    }
}
