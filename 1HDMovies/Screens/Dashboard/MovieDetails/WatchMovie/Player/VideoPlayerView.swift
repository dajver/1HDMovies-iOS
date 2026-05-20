import SwiftUI
import AVKit
import AVFoundation
import os

private let log = Logger(subsystem: "com.dajver.one.hd", category: "Subtitles")

struct VideoPlayerView: View {
    let url: String
    let referer: String
    var subtitles: [SubtitleTrack] = []
    let onClose: () -> Void

    @State private var presented = false

    var body: some View {
        Color.black.ignoresSafeArea()
            .onAppear {
                guard !presented else { return }
                presented = true
                presentPlayer()
            }
    }

    private func presentPlayer() {
        guard let videoURL = URL(string: url) else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let headers = [
            "Referer": referer,
            "Origin": referer.hasSuffix("/") ? String(referer.dropLast()) : referer,
            "User-Agent": Config.userAgent
        ]

        let asset = AVURLAsset(url: videoURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)

        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        playerVC.allowsPictureInPicturePlayback = true

        let coordinator = DismissCoordinator(onClose: onClose)
        playerVC.delegate = coordinator
        objc_setAssociatedObject(playerVC, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        log.info("Starting player with stream: \(url)")
        log.info("External subtitles count: \(subtitles.count)")
        for sub in subtitles {
            log.info("External subtitle: \(sub.label) - \(sub.url)")
        }

        let subtitleManager = SubtitleManager(
            player: player,
            playerItem: playerItem,
            streamUrl: url,
            referer: referer,
            externalSubtitles: subtitles,
            containerView: playerVC.view
        )
        objc_setAssociatedObject(playerVC, "subtitleManager", subtitleManager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(playerVC, animated: true) {
            player.play()
        }
    }
}

class DismissCoordinator: NSObject, AVPlayerViewControllerDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: nil) { _ in
            self.onClose()
        }
    }

    func playerViewControllerDidDismiss(_ playerViewController: AVPlayerViewController) {
        playerViewController.player?.pause()
        onClose()
    }
}

// MARK: - Subtitle Manager

class SubtitleManager: NSObject {
    private let player: AVPlayer
    private let playerItem: AVPlayerItem
    private let streamUrl: String
    private let referer: String
    private let externalSubtitles: [SubtitleTrack]
    private let containerView: UIView
    private var statusObservation: NSKeyValueObservation?

    // External subtitle overlay
    private var cues: [SubtitleCue] = []
    private var subtitleLabel: UILabel?
    private var timeObserver: Any?
    private var isOverlayEnabled = true
    private var ccButton: UIButton?

    init(player: AVPlayer, playerItem: AVPlayerItem, streamUrl: String, referer: String,
         externalSubtitles: [SubtitleTrack], containerView: UIView) {
        self.player = player
        self.playerItem = playerItem
        self.streamUrl = streamUrl
        self.referer = referer
        self.externalSubtitles = externalSubtitles
        self.containerView = containerView
        super.init()

        // 1. Try HLS subtitles when asset is ready
        statusObservation = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    self?.onPlayerReady()
                }
            }
        }

        // 2. Also try parsing the m3u8 manifest directly for subtitle playlist URLs
        parseM3U8ForSubtitles()

        // 3. Fallback: if player is already ready or observation missed, set up overlay directly
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.cues.isEmpty, !self.externalSubtitles.isEmpty else { return }
            log.info("Fallback: setting up subtitle overlay directly")
            self.setupOverlay()
            // Pick English first, otherwise first available
            let english = self.externalSubtitles.first { $0.label.lowercased().contains("english") }
            let selected = english ?? self.externalSubtitles.first!
            self.loadExternalSubtitle(from: selected.url)
        }
    }

    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        statusObservation?.invalidate()
    }

    private func onPlayerReady() {
        log.info("Player ready — checking for HLS subtitle tracks")

        // Check if AVPlayer found subtitle tracks in the HLS manifest
        if let subtitleGroup = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) {
            let options = subtitleGroup.options
            log.info("HLS legible options count: \(options.count)")
            for opt in options {
                log.info("  HLS subtitle: \(opt.displayName) lang=\(opt.locale?.languageCode ?? "?")")
            }
            if !options.isEmpty {
                let english = options.first { $0.locale?.languageCode == "en" }
                if let option = english ?? options.first {
                    playerItem.select(option, in: subtitleGroup)
                    log.info("Selected HLS subtitle: \(option.displayName)")
                }
                return
            }
        } else {
            log.info("No legible media selection group found")
        }

        // No HLS subtitles — use external subtitles if we have them
        log.info("External subtitles available: \(self.externalSubtitles.count)")
        if !self.externalSubtitles.isEmpty {
            setupOverlay()
            loadExternalSubtitle(from: externalSubtitles.first!.url)
        }
    }

    // MARK: - Parse m3u8 for subtitle VTT URLs

    private func parseM3U8ForSubtitles() {
        guard let url = URL(string: streamUrl) else { return }

        var request = URLRequest(url: url)
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue(Config.userAgent, forHTTPHeaderField: "User-Agent")

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let content = String(data: data, encoding: .utf8) else { return }

                log.info("m3u8 manifest content (\(content.count) chars):\n\(content.prefix(2000))")

                let subtitleUrls = extractSubtitleUrls(from: content, baseUrl: url)
                log.info("Found \(subtitleUrls.count) subtitle URLs in m3u8")
                for sub in subtitleUrls {
                    log.info("  m3u8 subtitle: \(sub.label) - \(sub.url)")
                }

                if !subtitleUrls.isEmpty {
                    await MainActor.run {
                        if self.cues.isEmpty {
                            self.setupOverlay()
                            self.loadExternalSubtitle(from: subtitleUrls.first!.url)
                        }
                    }
                }
            } catch {
                log.error("Failed to fetch m3u8: \(error.localizedDescription)")
            }
        }
    }

    private func extractSubtitleUrls(from m3u8Content: String, baseUrl: URL) -> [SubtitleTrack] {
        var tracks: [SubtitleTrack] = []
        let lines = m3u8Content.components(separatedBy: "\n")

        for (i, line) in lines.enumerated() {
            // Look for #EXT-X-MEDIA:TYPE=SUBTITLES
            if line.contains("TYPE=SUBTITLES") {
                let label = extractAttribute("NAME", from: line) ?? "Subtitles"
                let lang = extractAttribute("LANGUAGE", from: line) ?? ""
                if let uri = extractAttribute("URI", from: line) {
                    let fullUrl = resolveUrl(uri, relativeTo: baseUrl)
                    tracks.append(SubtitleTrack(label: label, url: fullUrl, language: lang))
                }
            }

            // Also look for lines after #EXTINF that end in .vtt
            if line.hasPrefix("#EXTINF"), i + 1 < lines.count {
                let nextLine = lines[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                if nextLine.hasSuffix(".vtt") {
                    let fullUrl = resolveUrl(nextLine, relativeTo: baseUrl)
                    tracks.append(SubtitleTrack(label: "Subtitles", url: fullUrl, language: ""))
                }
            }
        }
        return tracks
    }

    private func extractAttribute(_ name: String, from line: String) -> String? {
        let pattern = "\(name)=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return String(line[range])
        }
        // Also try without quotes
        let pattern2 = "\(name)=([^,\\s]+)"
        if let regex = try? NSRegularExpression(pattern: pattern2),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return String(line[range])
        }
        return nil
    }

    private func resolveUrl(_ path: String, relativeTo base: URL) -> String {
        if path.hasPrefix("http") { return path }
        if let resolved = URL(string: path, relativeTo: base) {
            return resolved.absoluteString
        }
        // Build from base URL directory
        let baseDir = base.deletingLastPathComponent()
        return baseDir.appendingPathComponent(path).absoluteString
    }

    // MARK: - Subtitle Overlay UI

    private func setupOverlay() {
        guard subtitleLabel == nil else { return }

        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = .zero
        label.layer.shadowRadius = 4
        label.layer.shadowOpacity = 1.0
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -32)
        ])
        subtitleLabel = label

        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        button.setImage(UIImage(systemName: "captions.bubble.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 20
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(toggleOverlay), for: .touchUpInside)

        containerView.addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40),
            button.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 12),
            button.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
        ccButton = button
    }

    @objc private func toggleOverlay() {
        isOverlayEnabled.toggle()
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let name = isOverlayEnabled ? "captions.bubble.fill" : "captions.bubble"
        ccButton?.setImage(UIImage(systemName: name, withConfiguration: config), for: .normal)
        if !isOverlayEnabled {
            subtitleLabel?.isHidden = true
        }
    }

    // MARK: - Load & Display

    private func loadExternalSubtitle(from urlString: String) {
        guard let url = URL(string: urlString) else {
            log.error("Invalid subtitle URL: \(urlString)")
            return
        }

        log.info("Loading subtitle from: \(urlString)")

        var request = URLRequest(url: url)
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue(Config.userAgent, forHTTPHeaderField: "User-Agent")

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let content = String(data: data, encoding: .utf8) else {
                    log.error("Failed to decode subtitle content")
                    return
                }

                log.info("Subtitle content loaded: \(content.count) chars, first 200: \(content.prefix(200))")

                // If this is a subtitle m3u8 playlist, extract the actual VTT URL
                if content.contains("#EXTM3U") {
                    let vttUrl = extractVttFromPlaylist(content, baseUrl: url)
                    if let vttUrl {
                        await MainActor.run { self.loadExternalSubtitle(from: vttUrl) }
                        return
                    }
                }

                let parsed = VTTParser.parse(content)
                log.info("Parsed \(parsed.count) subtitle cues")
                if let first = parsed.first {
                    log.info("First cue: \(first.startTime)-\(first.endTime): \(first.text.prefix(50))")
                }
                await MainActor.run {
                    self.cues = parsed
                    self.startTimeObserver()
                }
            } catch {
                log.error("Failed to load subtitle: \(error.localizedDescription)")
            }
        }
    }

    private func extractVttFromPlaylist(_ content: String, baseUrl: URL) -> String? {
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                return resolveUrl(trimmed, relativeTo: baseUrl)
            }
        }
        return nil
    }

    private func startTimeObserver() {
        guard !cues.isEmpty, timeObserver == nil else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateSubtitle(at: time.seconds)
        }
    }

    private func updateSubtitle(at time: TimeInterval) {
        guard isOverlayEnabled, let label = subtitleLabel else { return }
        if let cue = cues.first(where: { time >= $0.startTime && time <= $0.endTime }) {
            label.text = "  \(cue.text)  "
            label.isHidden = false
        } else {
            label.isHidden = true
        }
    }
}
