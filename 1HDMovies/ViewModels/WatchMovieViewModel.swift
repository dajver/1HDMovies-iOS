import Foundation
import SwiftSoup

@Observable
class WatchMovieViewModel {
    var embedUrl: String?
    var isLoading = true

    func fetchEmbedUrl(watchUrl: String) async {
        do {
            let html = try await HttpClient.shared.get(watchUrl)
            let pattern = "const pl_url = '([^']+)'"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let plUrl = String(html[range])
                let serverHtml = try await HttpClient.shared.get(plUrl)
                let doc = try SwiftSoup.parse(serverHtml)
                let firstServer = try doc.select("a.sv-item").first()
                let url = try firstServer?.attr("data-id")
                await MainActor.run {
                    self.embedUrl = url
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
}
