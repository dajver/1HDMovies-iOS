import SwiftUI
import AVKit
import AVFoundation
import os

private let log = Logger(subsystem: "com.dajver.one.hd", category: "Player")

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

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let subs = subtitles
        topVC.present(playerVC, animated: true) {
            player.play()
            if !subs.isEmpty {
                let manager = SubtitleManager(player: player, subtitles: subs, playerViewController: playerVC)
                objc_setAssociatedObject(playerVC, "subtitleManager", manager, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}

// MARK: - Dismiss Coordinator

class DismissCoordinator: NSObject, AVPlayerViewControllerDelegate {
    let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }

    func playerViewController(_ playerViewController: AVPlayerViewController,
                               willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: nil) { _ in self.onClose() }
    }

    func playerViewControllerDidDismiss(_ playerViewController: AVPlayerViewController) {
        playerViewController.player?.pause()
        onClose()
    }
}

// MARK: - Subtitle Manager

class SubtitleManager: NSObject {
    private let player: AVPlayer
    private let subtitles: [SubtitleTrack]
    private weak var playerViewController: AVPlayerViewController?

    private var cues: [SubtitleCue] = []
    private var subtitleLabel: UILabel?
    private var timeObserver: Any?
    private var isEnabled = true
    private var selectedTrack: SubtitleTrack?

    init(player: AVPlayer, subtitles: [SubtitleTrack], playerViewController: AVPlayerViewController) {
        self.player = player
        self.subtitles = subtitles
        self.playerViewController = playerViewController
        super.init()

        setupSubtitleLabel()

        // Auto-select English or first track
        let english = subtitles.first { $0.label.lowercased().contains("english") }
        if let track = english ?? subtitles.first {
            selectTrack(track)
        }
    }

    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }

    // MARK: - UI

    private func setupSubtitleLabel() {
        guard let overlay = playerViewController?.contentOverlayView else { return }

        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = .zero
        label.layer.shadowRadius = 4
        label.layer.shadowOpacity = 1.0
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.isHidden = true
        label.isUserInteractionEnabled = true
        label.translatesAutoresizingMaskIntoConstraints = false

        // Tap subtitle text to show language picker
        let tap = UITapGestureRecognizer(target: self, action: #selector(showSubtitlePicker))
        label.addGestureRecognizer(tap)

        overlay.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -80),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -40)
        ])
        subtitleLabel = label
    }

    @objc private func showSubtitlePicker() {
        guard let playerVC = playerViewController else { return }

        let alert = UIAlertController(title: "Subtitles", message: nil, preferredStyle: .actionSheet)

        let offTitle = !isEnabled ? "✓ Off" : "Off"
        alert.addAction(UIAlertAction(title: offTitle, style: .default) { [weak self] _ in
            self?.isEnabled = false
            self?.subtitleLabel?.isHidden = true
        })

        for track in subtitles {
            let isSelected = isEnabled && selectedTrack?.url == track.url
            let title = isSelected ? "✓ \(track.label)" : track.label
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.selectTrack(track)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = subtitleLabel
            popover.sourceRect = subtitleLabel?.bounds ?? .zero
        }

        playerVC.present(alert, animated: true)
    }

    // MARK: - Track Selection

    private func selectTrack(_ track: SubtitleTrack) {
        isEnabled = true
        selectedTrack = track
        cues = []
        subtitleLabel?.isHidden = true

        guard let url = URL(string: track.url) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let content = String(data: data, encoding: .utf8) else { return }
                let parsed = VTTParser.parse(content)
                await MainActor.run {
                    self.cues = parsed
                    self.startTimeObserver()
                }
            } catch {
                log.error("Failed to load subtitle: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Playback Sync

    private func startTimeObserver() {
        if let existing = timeObserver {
            player.removeTimeObserver(existing)
        }
        guard !cues.isEmpty else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateSubtitle(at: time.seconds)
        }
    }

    private func updateSubtitle(at time: TimeInterval) {
        guard isEnabled, let label = subtitleLabel else { return }
        if let cue = cues.first(where: { time >= $0.startTime && time <= $0.endTime }) {
            label.text = "  \(cue.text)  "
            label.isHidden = false
        } else {
            label.isHidden = true
        }
    }
}
