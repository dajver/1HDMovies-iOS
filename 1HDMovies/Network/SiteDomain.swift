import Foundation
import os

private let log = Logger(subsystem: "com.dajver.one.hd", category: "SiteDomain")

/// Resolves — and remembers — the domain the site is currently served from.
///
/// The site hops TLD every so often (`1hd.art` → `1hd.one` → …), which would
/// otherwise brick every scraping repo at once. Rather than trusting one
/// hardcoded host we probe a candidate list on failure, keep the first host that
/// serves markup the scrapers can actually parse, and persist it — so later
/// launches go straight to the live domain with no probing at all.
///
/// Nothing is probed on a successful request: `Config.baseURL` just reads the
/// cached host, and only a failed request triggers a re-resolve (see `HttpClient`).
enum SiteDomain {

    /// Probed in preference order. Some of these park (a placeholder page answers
    /// 200), which is why `looksLikeSite` — not the status code — decides.
    static let candidateHosts = [
        "1hd.one", "1hd.art", "1hd.cc", "1hd.to", "1hd.co", "1hd.com",
        "1hd.net", "1hd.io", "1hd.me", "1hd.tv", "1hd.la", "1hd.lat",
        "1hd.pro", "1hd.site", "1hd.top", "1hd.watch", "1hd.movie",
        "1hd.stream", "1hd.vip", "1hd.ru", "1hd.in", "1hd.sx", "1hd.gg"
    ]

    /// Shipped default, used until something better is resolved.
    static var defaultHost: String { candidateHosts[0] }

    /// The host every request currently goes to.
    static var host: String { HostStore.shared.host }

    static var baseURL: String { "https://\(host)" }

    // MARK: - URL building

    /// Points a URL at the live host if it belongs to the site, otherwise returns
    /// it untouched.
    ///
    /// Saved favorites, episode links and playback-progress keys embed whatever
    /// domain was live when they were stored. Rewriting only at request time keeps
    /// those records — and their Firestore document IDs — byte-for-byte stable
    /// while still reaching the site after a move.
    static func live(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString),
              let urlHost = components.host,
              isSiteHost(urlHost),
              urlHost != host
        else { return urlString }
        components.scheme = "https"
        components.host = host
        return components.string ?? urlString
    }

    /// Absolute, live URL for a scraped `href`, which may be site-absolute or a
    /// relative path.
    static func absolute(_ pathOrUrl: String) -> String {
        if pathOrUrl.hasPrefix("http") { return live(pathOrUrl) }
        let path = pathOrUrl.hasPrefix("/") ? pathOrUrl : "/\(pathOrUrl)"
        return baseURL + path
    }

    /// Whether a URL points at the site (as opposed to an embed / CDN host), and so
    /// is worth re-resolving the domain for when it fails.
    static func isSiteURL(_ urlString: String) -> Bool {
        guard let urlHost = URLComponents(string: urlString)?.host else { return false }
        return isSiteHost(urlHost)
    }

    /// Any host we've ever seen the site on, plus anything shaped like `1hd.*` —
    /// so a domain discovered via redirect is recognised before it's ever probed.
    static func isSiteHost(_ candidate: String) -> Bool {
        let bare = normalized(candidate)
        if HostStore.shared.knownHosts.contains(bare) { return true }
        return bare.hasPrefix("1hd.") || bare.contains(".1hd.")
    }

    static func normalized(_ candidate: String) -> String {
        let lowered = candidate.lowercased()
        return lowered.hasPrefix("www.") ? String(lowered.dropFirst(4)) : lowered
    }

    // MARK: - Resolution

    /// Re-probes the candidate list and adopts the first host serving a parsable
    /// page. Concurrent callers share a single probe run. Returns whether any live
    /// host was found (it may be the one already in use — a failure isn't always a
    /// domain move).
    @discardableResult
    static func rediscover() async -> Bool {
        await DomainResolver.shared.resolve()
    }

    fileprivate static func adopt(_ newHost: String) {
        let previous = host
        HostStore.shared.adopt(newHost)
        if previous != newHost {
            log.notice("site domain moved \(previous, privacy: .public) -> \(newHost, privacy: .public)")
        }
    }
}

// MARK: - Probing

private actor DomainResolver {
    static let shared = DomainResolver()

    /// A moved domain makes every in-flight request fail at once; coalescing them
    /// onto one probe run keeps that from turning into a burst of ~20 × N requests.
    private var inFlight: Task<Bool, Never>?

    func resolve() async -> Bool {
        if let inFlight { return await inFlight.value }
        let task = Task<Bool, Never> { await Self.probeCandidates() }
        inFlight = task
        let found = await task.value
        inFlight = nil
        return found
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static func probeCandidates() async -> Bool {
        // Every candidate is probed at once and the one highest in preference order
        // wins. Probing the current host first instead would cost a full timeout
        // before the fan-out even starts — and it's the host that just failed, so
        // it's the least likely to answer.
        var ordered = [SiteDomain.host]
        ordered += SiteDomain.candidateHosts.filter { $0 != SiteDomain.host }

        let winner: String? = await withTaskGroup(of: (Int, String?).self) { group in
            for (index, candidate) in ordered.enumerated() {
                group.addTask { (index, await probe(host: candidate)) }
            }
            var best: (index: Int, host: String)?
            for await (index, resolved) in group {
                guard let resolved else { continue }
                if best == nil || index < best!.index { best = (index, resolved) }
                // Nothing can outrank the preferred host, so don't wait on the
                // dead candidates still burning their timeouts.
                if best?.index == 0 {
                    group.cancelAll()
                    break
                }
            }
            return best?.host
        }

        if let winner {
            SiteDomain.adopt(winner)
            return true
        }
        log.error("no live site domain found across \(ordered.count) candidates")
        return false
    }

    /// Returns the host that actually served the page, or nil if this one is dead
    /// or parked.
    private static func probe(host: String) async -> String? {
        guard let url = URL(string: "https://\(host)/home") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(Config.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                         forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let html = String(data: data, encoding: .utf8),
                  looksLikeSite(html)
            else { return nil }
            // Report where we *landed*, not what we asked for: an abandoned domain
            // redirecting to a brand-new one teaches us a host that isn't in the
            // candidate list at all.
            let landed = response.url?.host.map(SiteDomain.normalized)
            return landed ?? host
        } catch {
            return nil
        }
    }

    /// Dead domains are frequently parked on a placeholder that answers 200, so
    /// only accept markup the scraping repos can actually parse: the home carousel
    /// plus at least one movie link.
    private static func looksLikeSite(_ html: String) -> Bool {
        html.contains("swiper-slide") && html.contains("/movie/")
    }
}

// MARK: - Persistence

/// Thread-safe cache of the resolved host, backed by `UserDefaults` so the search
/// only ever happens once per domain move — not once per launch.
private final class HostStore: @unchecked Sendable {
    static let shared = HostStore()

    private static let hostKey = "site.resolvedHost"
    private static let knownHostsKey = "site.knownHosts"

    private let lock = NSLock()
    private var cachedHost: String
    private var cachedKnownHosts: Set<String>

    private init() {
        let defaults = UserDefaults.standard
        cachedHost = defaults.string(forKey: Self.hostKey) ?? SiteDomain.defaultHost
        cachedKnownHosts = Set(SiteDomain.candidateHosts)
            .union(defaults.stringArray(forKey: Self.knownHostsKey) ?? [])
            .union([cachedHost])
    }

    var host: String {
        lock.lock(); defer { lock.unlock() }
        return cachedHost
    }

    var knownHosts: Set<String> {
        lock.lock(); defer { lock.unlock() }
        return cachedKnownHosts
    }

    func adopt(_ newHost: String) {
        lock.lock()
        cachedHost = newHost
        cachedKnownHosts.insert(newHost)
        let known = Array(cachedKnownHosts)
        lock.unlock()

        let defaults = UserDefaults.standard
        defaults.set(newHost, forKey: Self.hostKey)
        defaults.set(known, forKey: Self.knownHostsKey)
    }
}
