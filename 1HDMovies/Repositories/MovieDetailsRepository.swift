import Foundation
import SwiftSoup

class MovieDetailsRepository {
    static let shared = MovieDetailsRepository()

    func fetchDetails(url: String) async throws -> MoviesDetailsDataModel {
        let linkToMovieDetails = url.hasPrefix("https://1hd") ? url : "\(Config.baseURL)\(url)"
        let html = try await HttpClient.shared.get(linkToMovieDetails)
        let doc = try SwiftSoup.parse(html)
        let type: MovieType = linkToMovieDetails.contains("movie") ? .movie : .tvShow
        let movieDetails = try doc.select("div.detail-elements")
        let thumbnail = try movieDetails.select("img.film-thumbnail-img").attr("src")
        let title = try movieDetails.select(".heading-xl").text()
        let quality = try movieDetails.select("div.quality").text()
        let linkToWatch = try movieDetails.select("div.div-buttons").select("a").attr("href")
        let description = try movieDetails.select("div.description").text()
        let others = try movieDetails.select("div.others")
        let cast = try others.select("div.item-casts").select("div.item-body").text()
        let genre = try others.select("div.item-genres").select("div.item-body").text()
        let ratingAndOther = try others.select("div.item").select("div.item-body").eachText()
        let duration = ratingAndOther.count > 2 ? ratingAndOther[2] : ""
        let country = ratingAndOther.count > 3 ? ratingAndOther[3] : ""
        let imdb = ratingAndOther.count > 4 ? ratingAndOther[4] : ""
        let release = ratingAndOther.count > 5 ? ratingAndOther[5] : ""
        let production = ratingAndOther.count > 6 ? ratingAndOther[6] : ""

        let fullLinkToWatch = linkToWatch.hasPrefix("https://") ? linkToWatch : "\(Config.baseURL)\(linkToWatch)"
        let watchMovieLinkWithEpisodeId = fullLinkToWatch

        if type == .movie {
            return MoviesDetailsDataModel(
                name: title, thumbnail: thumbnail, linkToWatch: linkToWatch,
                linkToDetails: linkToMovieDetails, watchMovieLinkWithEpisodeId: watchMovieLinkWithEpisodeId,
                type: type, description: description, quality: quality, cast: cast, genre: genre,
                duration: duration, country: country, imdb: imdb, release: release, production: production
            )
        } else {
            let seasons = try await getSeasons(doc: doc)
            return MoviesDetailsDataModel(
                name: title, thumbnail: thumbnail, linkToWatch: linkToWatch,
                linkToDetails: linkToMovieDetails, watchMovieLinkWithEpisodeId: watchMovieLinkWithEpisodeId,
                type: type, description: description, quality: quality, cast: cast, genre: genre,
                duration: duration, country: country, imdb: imdb, release: release, production: production,
                seasonsList: seasons
            )
        }
    }

    private func getSeasons(doc: Document) async throws -> [MovieSeasonDataModel] {
        do {
            let seasonElements = try doc.select("div.is-seasons").select("a.ss-item")
            var seasons: [MovieSeasonDataModel] = []
            for element in seasonElements.array() {
                let seasonHash = try element.attr("data-id")
                let seasonNumber = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                let episodes = try await getEpisodes(seasonHash: seasonHash)
                seasons.append(MovieSeasonDataModel(seasonId: seasonHash, seasonNumber: seasonNumber, episodes: episodes))
            }
            return seasons
        } catch {
            return []
        }
    }

    private func getEpisodes(seasonHash: String) async throws -> [MovieEpisodesDataModel] {
        do {
            let ajaxLink = "\(Config.baseURL)/ajax/ajax.php?episode=\(seasonHash)"
            let html = try await HttpClient.shared.get(ajaxLink)
            let doc = try SwiftSoup.parse(html)
            let episodeElements = try doc.select("a.ep-item")
            var episodes: [MovieEpisodesDataModel] = []
            for element in episodeElements.array() {
                let episodeNumber = try element.select("span.number").text().trimmingCharacters(in: .whitespacesAndNewlines)
                let episodeName = try element.select("span.name").text().trimmingCharacters(in: .whitespacesAndNewlines)
                let href = try element.attr("href")
                let link = href.hasPrefix("https://1hd") ? href : "\(Config.baseURL)\(href)"
                episodes.append(MovieEpisodesDataModel(episodeNumber: episodeNumber, episodeName: episodeName, link: link))
            }
            return episodes
        } catch {
            return []
        }
    }
}
