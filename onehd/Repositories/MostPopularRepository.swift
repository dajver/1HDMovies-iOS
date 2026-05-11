import Foundation
import SwiftSoup

class MostPopularRepository {
    static let shared = MostPopularRepository()

    func fetchMostPopular() async throws -> [MostPopularMoviesDataModel] {
        let html = try await HttpClient.shared.get("\(Config.baseURL)/home")
        let doc = try SwiftSoup.parse(html)
        let moviesElements = try doc.select("div.swiper-wrapper")
        let movieDetailsContainer = try moviesElements.select("div.container").select("div.is-caption")
        let thumbnails = try moviesElements.select("div.slide-cover").select("img").eachAttr("src")

        let qualityAndYearElements = try movieDetailsContainer.select("span.item")
        var qualityAndYear: [String] = []
        for element in qualityAndYearElements.array() {
            for textNode in element.textNodes() {
                let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    qualityAndYear.append(text)
                }
            }
        }

        var qualities: [String] = []
        var i = 0
        while i < qualityAndYear.count - 2 {
            let quality = qualityAndYear[i]
            let type = qualityAndYear[i + 1]
            let year = qualityAndYear[i + 2]
            qualities.append("\(quality), \(type), \(year)")
            i += 3
        }

        let names = try movieDetailsContainer.select("a").eachAttr("title")
        let descriptionElements = try movieDetailsContainer.select("p.description")
        var descriptions: [String] = []
        for element in descriptionElements.array() {
            for textNode in element.textNodes() {
                let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    descriptions.append(text)
                }
            }
        }
        let links = try movieDetailsContainer.select("div.div-buttons").select("a").eachAttr("href")

        var movies: [MostPopularMoviesDataModel] = []
        for index in 0..<thumbnails.count {
            guard index < names.count, index < links.count else { break }
            let name = names[index]
            let thumbnail = thumbnails[index]
            let link = links[index]
            let watchMovieLink = link.hasPrefix("https://1hd") ? link : "\(Config.baseURL)\(link)"
            let description = index < descriptions.count ? descriptions[index] : ""
            let quality = index < qualities.count ? qualities[index] : ""
            movies.append(MostPopularMoviesDataModel(name: name, thumbnail: thumbnail, link: watchMovieLink, quality: quality, description: description))
        }
        return movies
    }
}
