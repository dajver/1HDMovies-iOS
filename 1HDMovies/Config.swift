import Foundation

enum Config {
    /// Resolved at runtime rather than hardcoded — the site moves TLD periodically.
    /// See `SiteDomain`.
    static var baseURL: String { SiteDomain.baseURL }
    static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.82 Safari/537.36"
}
