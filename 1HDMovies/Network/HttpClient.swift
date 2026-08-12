import Foundation

class HttpClient {
    static let shared = HttpClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent": Config.userAgent,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5"
        ]
        session = URLSession(configuration: config)
    }

    /// Fetches a page, pointing site URLs at whichever domain is currently live.
    ///
    /// A failure on a site URL is treated as a possible domain move: the candidate
    /// list is re-probed once and the request retried against the resolved host, so
    /// a move heals mid-session without the user seeing anything but a slower load.
    /// Non-site URLs (embed / CDN hosts) fail through untouched.
    func get(_ urlString: String) async throws -> String {
        do {
            return try await fetch(SiteDomain.live(urlString))
        } catch {
            guard SiteDomain.isSiteURL(urlString) else { throw error }
            guard await SiteDomain.rediscover() else { throw error }
            return try await fetch(SiteDomain.live(urlString))
        }
    }

    private func fetch(_ urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return html
    }
}
