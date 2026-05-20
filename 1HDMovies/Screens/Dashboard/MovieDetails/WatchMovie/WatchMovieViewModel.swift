import Foundation
import SwiftSoup

struct ServerOption: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let embedUrl: String
}

@Observable
class WatchMovieViewModel {
    var embedUrl: String?
    var servers: [ServerOption] = []
    var selectedServer: ServerOption?
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
                let serverElements = try doc.select("a.sv-item")

                var options: [ServerOption] = []
                for element in serverElements {
                    let name = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    let url = try element.attr("data-id")
                    if !url.isEmpty {
                        options.append(ServerOption(name: name, embedUrl: url))
                    }
                }

                await MainActor.run {
                    self.servers = options
                    if let first = options.first {
                        self.selectedServer = first
                        self.embedUrl = first.embedUrl
                    }
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }

    func selectServer(_ server: ServerOption) {
        selectedServer = server
        embedUrl = server.embedUrl
    }
}
