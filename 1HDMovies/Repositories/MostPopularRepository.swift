import Foundation
import SwiftSoup

class MostPopularRepository {
    static let shared = MostPopularRepository()

    func fetchMostPopular() async throws -> [MostPopularMoviesDataModel] {
        let html = try await HttpClient.shared.get("\(Config.baseURL)/home")
        let doc = try SwiftSoup.parse(html)
        let slides = try doc.select("div.swiper-wrapper div.swiper-slide")

        var movies: [MostPopularMoviesDataModel] = []
        var seen = Set<String>()

        // Parse each slide as a self-contained unit so the poster, name and link
        // always belong to the same movie (the page's parallel lists don't align —
        // some slides have no cover and the swiper duplicates slides for looping).
        for slide in slides.array() {
            let captionLink = try slide.select("div.is-caption a[title]").first()
            var href = (try captionLink?.attr("href")) ?? ""
            if href.isEmpty {
                href = (try slide.select("div.div-buttons a").first()?.attr("href")) ?? ""
            }
            guard !href.isEmpty else { continue }
            let link = href.hasPrefix("https://1hd") ? href : "\(Config.baseURL)\(href)"
            guard !seen.contains(link) else { continue }

            let name = (try captionLink?.attr("title")) ?? ""
            guard !name.isEmpty else { continue }

            let thumbnail = (try slide.select("div.slide-cover img").first()?.attr("src")) ?? ""

            var qualityParts: [String] = []
            for element in try slide.select("div.is-caption span.item").array() {
                for node in element.textNodes() {
                    let text = node.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { qualityParts.append(text) }
                }
            }
            let quality = qualityParts.prefix(3).joined(separator: ", ")

            var description = ""
            if let descriptionElement = try slide.select("p.description").first() {
                description = try descriptionElement.text()
            }

            seen.insert(link)
            movies.append(MostPopularMoviesDataModel(
                name: name, thumbnail: thumbnail, link: link,
                quality: quality, description: description
            ))
        }
        return movies
    }
}
