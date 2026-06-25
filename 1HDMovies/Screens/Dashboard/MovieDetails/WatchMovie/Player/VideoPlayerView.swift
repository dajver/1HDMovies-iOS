import SwiftUI
import AVKit
import AVFoundation
import os

private let log = Logger(subsystem: "com.dajver.one.hd", category: "Player")

struct VideoPlayerView: View {
    let url: String
    let referer: String
    var subtitles: [SubtitleTrack] = []
    var episodes: [MovieEpisodesDataModel] = []
    var currentEpisodeIndex: Int = 0
    var servers: [ServerOption] = []
    var selectedServer: ServerOption?
    let onClose: () -> Void
    var onEpisodeChange: ((Int) -> Void)?
    var onServerChange: ((ServerOption) -> Void)?
    var onWatchedReached: (() -> Void)?

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

        let playerVC = CustomPlayerViewController(
            player: player,
            subtitles: subtitles,
            episodes: episodes,
            currentEpisodeIndex: currentEpisodeIndex,
            servers: servers,
            selectedServer: selectedServer,
            onClose: onClose,
            onEpisodeChange: onEpisodeChange,
            onServerChange: onServerChange,
            onWatchedReached: onWatchedReached
        )
        playerVC.modalPresentationStyle = .fullScreen

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

// MARK: - Custom Player View Controller

class CustomPlayerViewController: UIViewController {
    private let player: AVPlayer
    private let subtitles: [SubtitleTrack]
    private let episodes: [MovieEpisodesDataModel]
    private let currentEpisodeIndex: Int
    private let servers: [ServerOption]
    private let selectedServer: ServerOption?
    private let onClose: () -> Void
    private let onEpisodeChange: ((Int) -> Void)?
    private let onServerChange: ((ServerOption) -> Void)?
    private let onWatchedReached: (() -> Void)?

    /// Mark the episode watched after this many seconds of playback position.
    private let watchedThreshold: Double = 300
    private var hasReachedWatchedThreshold = false

    // Video layer
    private var playerLayer: AVPlayerLayer!

    // Controls
    private let controlsContainer = UIView()
    private let topBar = UIView()
    private let episodeLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    private let seekBar = UISlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let rewindButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let prevEpisodeButton = UIButton(type: .system)
    private let nextEpisodeButton = UIButton(type: .system)

    // Bottom options row (below seek bar)
    private let subtitlesButton = UIButton(type: .system)
    private let speedButton = UIButton(type: .system)
    private let serverButton = UIButton(type: .system)
    private var optionsStack: UIStackView?
    private var optionsRowHeightConstraint: NSLayoutConstraint?

    // Subtitles
    private let subtitleLabel = UILabel()
    private var cues: [SubtitleCue] = []
    private var subtitlesEnabled = true
    private var selectedTrack: SubtitleTrack?
    private var timeObserver: Any?

    // Speed
    private var currentSpeed: Float = 1.0
    private let speeds: [Float] = [0.5, 1.0, 1.5, 2.0]

    // Controls visibility
    private var controlsVisible = true
    private var hideControlsTask: Task<Void, Never>?
    private var isSeeking = false

    // Observations
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?

    init(player: AVPlayer, subtitles: [SubtitleTrack], episodes: [MovieEpisodesDataModel],
         currentEpisodeIndex: Int, servers: [ServerOption], selectedServer: ServerOption?,
         onClose: @escaping () -> Void, onEpisodeChange: ((Int) -> Void)?,
         onServerChange: ((ServerOption) -> Void)?, onWatchedReached: (() -> Void)?) {
        self.player = player
        self.subtitles = subtitles
        self.episodes = episodes
        self.currentEpisodeIndex = currentEpisodeIndex
        self.servers = servers
        self.selectedServer = selectedServer
        self.onClose = onClose
        self.onEpisodeChange = onEpisodeChange
        self.onServerChange = onServerChange
        self.onWatchedReached = onWatchedReached
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Sizing

    /// Controls are enlarged on iPad where there's more screen and touch targets
    /// benefit from being bigger / further apart.
    private var isPad: Bool { traitCollection.userInterfaceIdiom == .pad }
    private func scaled(_ base: CGFloat) -> CGFloat { isPad ? base * 1.6 : base }

    private var isPanelVisible: Bool { view.subviews.contains { $0 is PickerPanelView } }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPlayerLayer()
        setupSubtitleLabel()
        setupControls()
        setupGestures()
        setupObservers()

        if !subtitles.isEmpty {
            let english = subtitles.first { $0.label.lowercased().contains("english") }
            if let track = english ?? subtitles.first {
                selectTrack(track)
            }
        }

        scheduleHideControls()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer.frame = view.bounds
        updateOptionsLayout()
    }

    private func updateOptionsLayout() {
        guard let stack = optionsStack else { return }
        let isLandscape = view.bounds.width > view.bounds.height
        if isLandscape {
            // Landscape: everything in one horizontal row
            stack.axis = .horizontal
            stack.spacing = 24
        } else {
            // Portrait: [Subtitles | Speed] on top, Server below
            stack.axis = .vertical
            stack.spacing = 4
        }
    }

    deinit {
        if let observer = timeObserver { player.removeTimeObserver(observer) }
        statusObservation?.invalidate()
        timeControlObservation?.invalidate()
    }

    // MARK: - Setup

    private func setupPlayerLayer() {
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
    }

    private func setupSubtitleLabel() {
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textColor = .white
        subtitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        subtitleLabel.layer.shadowColor = UIColor.black.cgColor
        subtitleLabel.layer.shadowOffset = .zero
        subtitleLabel.layer.shadowRadius = 4
        subtitleLabel.layer.shadowOpacity = 1.0
        subtitleLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        subtitleLabel.layer.cornerRadius = 4
        subtitleLabel.clipsToBounds = true
        subtitleLabel.isHidden = true
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 60),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -60)
        ])
    }

    private func setupControls() {
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsContainer)
        NSLayoutConstraint.activate([
            controlsContainer.topAnchor.constraint(equalTo: view.topAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Top bar — close button
        topBar.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44)
        ])

        configureSymbolButton(closeButton, systemName: "xmark", size: 18)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topBar.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Episode label (top bar, center)
        if !episodes.isEmpty {
            let ep = episodes[currentEpisodeIndex]
            episodeLabel.text = ep.episodeName.isEmpty ? ep.episodeNumber : "\(ep.episodeNumber) - \(ep.episodeName)"
            episodeLabel.font = .systemFont(ofSize: 15, weight: .medium)
            episodeLabel.textColor = .white
            episodeLabel.textAlignment = .center
            episodeLabel.translatesAutoresizingMaskIntoConstraints = false
            topBar.addSubview(episodeLabel)
            NSLayoutConstraint.activate([
                episodeLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
                episodeLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
                episodeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
                episodeLabel.trailingAnchor.constraint(lessThanOrEqualTo: topBar.trailingAnchor, constant: -52)
            ])
        }

        // Center controls
        let hasEpisodes = episodes.count > 1

        configureSymbolButton(prevEpisodeButton, systemName: "backward.end.fill", size: scaled(24))
        configureSymbolButton(rewindButton, systemName: "gobackward.10", size: scaled(30))
        configureSymbolButton(playPauseButton, systemName: "pause.fill", size: scaled(38))
        configureSymbolButton(forwardButton, systemName: "goforward.10", size: scaled(30))
        configureSymbolButton(nextEpisodeButton, systemName: "forward.end.fill", size: scaled(24))

        prevEpisodeButton.addTarget(self, action: #selector(prevEpisodeTapped), for: .touchUpInside)
        rewindButton.addTarget(self, action: #selector(rewindTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)
        nextEpisodeButton.addTarget(self, action: #selector(nextEpisodeTapped), for: .touchUpInside)

        prevEpisodeButton.isEnabled = currentEpisodeIndex > 0
        prevEpisodeButton.alpha = currentEpisodeIndex > 0 ? 1.0 : 0.3
        nextEpisodeButton.isEnabled = currentEpisodeIndex < episodes.count - 1
        nextEpisodeButton.alpha = currentEpisodeIndex < episodes.count - 1 ? 1.0 : 0.3

        // Center stack: prev / play-pause / next. The seek (±10s) buttons live at the
        // far left/right screen edges (added below) so they're easy to reach.
        var centerItems: [UIView] = []
        if hasEpisodes { centerItems.append(prevEpisodeButton) }
        centerItems.append(playPauseButton)
        if hasEpisodes { centerItems.append(nextEpisodeButton) }

        let centerStack = UIStackView(arrangedSubviews: centerItems)
        centerStack.axis = .horizontal
        centerStack.spacing = scaled(56)
        centerStack.alignment = .center
        centerStack.translatesAutoresizingMaskIntoConstraints = false

        controlsContainer.addSubview(centerStack)
        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor)
        ])

        // Seek buttons pinned to the very left / right edges with a generous tap area.
        let edgeInset = scaled(28)
        let tapSize = scaled(64)
        controlsContainer.addSubview(rewindButton)
        controlsContainer.addSubview(forwardButton)
        NSLayoutConstraint.activate([
            rewindButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: edgeInset),
            rewindButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            rewindButton.widthAnchor.constraint(equalToConstant: tapSize),
            rewindButton.heightAnchor.constraint(equalToConstant: tapSize),
            forwardButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -edgeInset),
            forwardButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: tapSize),
            forwardButton.heightAnchor.constraint(equalToConstant: tapSize)
        ])

        // Seek bar row
        let seekRow = UIView()
        seekRow.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(seekRow)

        currentTimeLabel.text = "0:00"
        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        currentTimeLabel.textColor = .white
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        durationLabel.text = "0:00"
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        durationLabel.textColor = .white
        durationLabel.translatesAutoresizingMaskIntoConstraints = false

        seekBar.minimumTrackTintColor = .white
        seekBar.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        seekBar.thumbTintColor = .white
        seekBar.translatesAutoresizingMaskIntoConstraints = false
        seekBar.addTarget(self, action: #selector(seekStarted), for: .touchDown)
        seekBar.addTarget(self, action: #selector(seekChanged), for: .valueChanged)
        seekBar.addTarget(self, action: #selector(seekEnded), for: [.touchUpInside, .touchUpOutside])

        seekRow.addSubview(currentTimeLabel)
        seekRow.addSubview(seekBar)
        seekRow.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            seekRow.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            seekRow.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            seekRow.heightAnchor.constraint(equalToConstant: 28),
            currentTimeLabel.leadingAnchor.constraint(equalTo: seekRow.leadingAnchor),
            currentTimeLabel.centerYAnchor.constraint(equalTo: seekRow.centerYAnchor),
            currentTimeLabel.widthAnchor.constraint(equalToConstant: 52),
            seekBar.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 8),
            seekBar.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),
            seekBar.centerYAnchor.constraint(equalTo: seekRow.centerYAnchor),
            durationLabel.trailingAnchor.constraint(equalTo: seekRow.trailingAnchor),
            durationLabel.centerYAnchor.constraint(equalTo: seekRow.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 52)
        ])

        // Options row (below seek bar) — Subtitles & Speed
        let optionsRow = UIView()
        optionsRow.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(optionsRow)

        NSLayoutConstraint.activate([
            seekRow.bottomAnchor.constraint(equalTo: optionsRow.topAnchor, constant: -4),
            optionsRow.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            optionsRow.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            optionsRow.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            optionsRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])

        // Subtitles button
        configureTextButton(subtitlesButton, icon: "captions.bubble.fill", title: "Subtitles")
        subtitlesButton.addTarget(self, action: #selector(ccTapped), for: .touchUpInside)
        subtitlesButton.isHidden = subtitles.isEmpty
        optionsRow.addSubview(subtitlesButton)

        // Speed button
        configureTextButton(speedButton, icon: "speedometer", title: "Speed (1x)")
        speedButton.addTarget(self, action: #selector(speedTapped), for: .touchUpInside)
        optionsRow.addSubview(speedButton)

        // Server button
        let serverName = selectedServer?.name ?? "Server"
        configureTextButton(serverButton, icon: "server.rack", title: serverName)
        serverButton.addTarget(self, action: #selector(serverTapped), for: .touchUpInside)
        serverButton.isHidden = servers.count <= 1
        optionsRow.addSubview(serverButton)

        // Row 1: Subtitles + Speed (always horizontal)
        var row1Items: [UIView] = []
        if !subtitles.isEmpty { row1Items.append(subtitlesButton) }
        row1Items.append(speedButton)

        let row1Stack = UIStackView(arrangedSubviews: row1Items)
        row1Stack.axis = .horizontal
        row1Stack.spacing = 24
        row1Stack.alignment = .center
        row1Stack.translatesAutoresizingMaskIntoConstraints = false

        // Outer stack: row1 on top, server below (vertical in portrait, horizontal in landscape)
        var outerItems: [UIView] = [row1Stack]
        if servers.count > 1 { outerItems.append(serverButton) }

        optionsStack = UIStackView(arrangedSubviews: outerItems)
        optionsStack!.alignment = .center
        optionsStack!.translatesAutoresizingMaskIntoConstraints = false
        optionsRow.addSubview(optionsStack!)

        NSLayoutConstraint.activate([
            optionsStack!.centerXAnchor.constraint(equalTo: optionsRow.centerXAnchor),
            optionsStack!.topAnchor.constraint(equalTo: optionsRow.topAnchor),
            optionsStack!.bottomAnchor.constraint(lessThanOrEqualTo: optionsRow.bottomAnchor),
            subtitlesButton.heightAnchor.constraint(equalToConstant: 32),
            speedButton.heightAnchor.constraint(equalToConstant: 32),
            serverButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        updateOptionsLayout()
    }

    private func configureSymbolButton(_ button: UIButton, systemName: String, size: CGFloat) {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureTextButton(_ button: UIButton, icon: String, title: String) {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        config.title = title
        config.baseForegroundColor = .white
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 13, weight: .medium)
            return out
        }
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupGestures() {
        // Double-tap left/right to seek -10/+10 (YouTube-style).
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        view.addGestureRecognizer(doubleTap)

        // Single tap toggles the controls; wait for the double-tap to fail first.
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        tap.delegate = self
        tap.require(toFail: doubleTap)
        view.addGestureRecognizer(tap)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard !isPanelVisible else { return }
        let width = view.bounds.width
        guard width > 0 else { return }
        let x = gesture.location(in: view).x
        // Left 40% rewinds, right 40% fast-forwards; the middle is left for play/pause.
        if x < width * 0.4 {
            seekBy(-10)
            showSeekFeedback(forward: false)
        } else if x > width * 0.6 {
            seekBy(10)
            showSeekFeedback(forward: true)
        }
    }

    /// Brief side pill ("−10s" / "+10s") shown when double-tap seeking.
    private func showSeekFeedback(forward: Bool) {
        let pill = UILabel()
        pill.text = forward ? "+10s" : "−10s"
        pill.font = .systemFont(ofSize: scaled(16), weight: .bold)
        pill.textColor = .white
        pill.textAlignment = .center
        pill.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        pill.layer.cornerRadius = scaled(22)
        pill.clipsToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pill)

        let sideConstraint = forward
            ? pill.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -scaled(56))
            : pill.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: scaled(56))
        NSLayoutConstraint.activate([
            pill.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            sideConstraint,
            pill.widthAnchor.constraint(equalToConstant: scaled(92)),
            pill.heightAnchor.constraint(equalToConstant: scaled(44))
        ])

        pill.alpha = 0
        UIView.animate(withDuration: 0.12, animations: { pill.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.35, delay: 0.3, options: []) {
                pill.alpha = 0
            } completion: { _ in
                pill.removeFromSuperview()
            }
        }
    }

    private func setupObservers() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateTime(time)
            self?.updateSubtitle(at: time.seconds)
            self?.checkWatchedThreshold(at: time.seconds)
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                let isPlaying = player.timeControlStatus == .playing
                let name = isPlaying ? "pause.fill" : "play.fill"
                let cfg = UIImage.SymbolConfiguration(pointSize: self.scaled(38), weight: .medium)
                self.playPauseButton.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
            }
        }

        statusObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    let duration = CMTimeGetSeconds(item.duration)
                    self?.seekBar.maximumValue = Float(duration)
                    self?.durationLabel.text = self?.formatTime(duration)
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        player.pause()
        dismiss(animated: true) { self.onClose() }
    }

    @objc private func prevEpisodeTapped() {
        guard currentEpisodeIndex > 0 else { return }
        player.pause()
        dismiss(animated: true) { self.onEpisodeChange?(self.currentEpisodeIndex - 1) }
    }

    @objc private func nextEpisodeTapped() {
        guard currentEpisodeIndex < episodes.count - 1 else { return }
        player.pause()
        dismiss(animated: true) { self.onEpisodeChange?(self.currentEpisodeIndex + 1) }
    }

    @objc private func playPauseTapped() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
            scheduleHideControls()
        }
    }

    @objc private func rewindTapped() { seekBy(-10) }

    @objc private func forwardTapped() { seekBy(10) }

    private func seekBy(_ delta: Double) {
        let t = CMTimeGetSeconds(player.currentTime())
        guard t.isFinite else { return }
        var target = t + delta
        let d = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        if d.isFinite { target = min(target, d) }
        player.seek(to: CMTime(seconds: max(0, target), preferredTimescale: 1))
    }

    @objc private func seekStarted() { isSeeking = true }

    @objc private func seekChanged() {
        let time = CMTime(seconds: Double(seekBar.value), preferredTimescale: 1)
        currentTimeLabel.text = formatTime(Double(seekBar.value))
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    @objc private func seekEnded() {
        isSeeking = false
    }

    @objc private func toggleControls() {
        controlsVisible.toggle()
        hideControlsTask?.cancel()
        UIView.animate(withDuration: 0.25) {
            self.controlsContainer.alpha = self.controlsVisible ? 1 : 0
        }
        // Only auto-hide if currently playing
        if controlsVisible && player.timeControlStatus == .playing {
            scheduleHideControls()
        }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, !isSeeking else { return }
            controlsVisible = false
            UIView.animate(withDuration: 0.25) { self.controlsContainer.alpha = 0 }
        }
    }

    // MARK: - Subtitles

    @objc private func ccTapped() {
        showPickerPanel(title: "Subtitles", items: buildSubtitleItems())
    }

    private func buildSubtitleItems() -> [PickerItem] {
        var items: [PickerItem] = []
        items.append(PickerItem(title: "Off", isSelected: !subtitlesEnabled) { [weak self] in
            self?.subtitlesEnabled = false
            self?.subtitleLabel.isHidden = true
            self?.updateSubtitlesButtonTitle()
        })
        for track in subtitles {
            let isSelected = subtitlesEnabled && selectedTrack?.url == track.url
            items.append(PickerItem(title: track.label, isSelected: isSelected) { [weak self] in
                self?.selectTrack(track)
            })
        }
        return items
    }

    private func selectTrack(_ track: SubtitleTrack) {
        subtitlesEnabled = true
        selectedTrack = track
        cues = []
        subtitleLabel.isHidden = true
        updateSubtitlesButtonTitle()

        guard let url = URL(string: track.url) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let content = String(data: data, encoding: .utf8) else { return }
                let parsed = VTTParser.parse(content)
                await MainActor.run { self.cues = parsed }
            } catch {
                log.error("Failed to load subtitle: \(error.localizedDescription)")
            }
        }
    }

    private func updateSubtitlesButtonTitle() {
        let icon = subtitlesEnabled ? "captions.bubble.fill" : "captions.bubble"
        let title = subtitlesEnabled ? (selectedTrack?.label ?? "Subtitles") : "Subtitles"
        configureTextButton(subtitlesButton, icon: icon, title: title)
    }

    private func updateSubtitle(at time: TimeInterval) {
        guard subtitlesEnabled else { return }
        if let cue = cues.first(where: { time >= $0.startTime && time <= $0.endTime }) {
            subtitleLabel.text = "  \(cue.text)  "
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
    }

    // MARK: - Speed

    @objc private func speedTapped() {
        var items: [PickerItem] = []
        for speed in speeds {
            let label = speed == 1.0 ? "Normal" : "\(speed)x"
            items.append(PickerItem(title: label, isSelected: speed == currentSpeed) { [weak self] in
                self?.setSpeed(speed)
            })
        }
        showPickerPanel(title: "Playback Speed", items: items)
    }

    // MARK: - Server

    @objc private func serverTapped() {
        var items: [PickerItem] = []
        for server in servers {
            let isSelected = server.id == selectedServer?.id
            items.append(PickerItem(title: server.name, isSelected: isSelected) { [weak self] in
                self?.player.pause()
                self?.dismiss(animated: true) {
                    self?.onServerChange?(server)
                }
            })
        }
        showPickerPanel(title: "Server", items: items)
    }

    private func setSpeed(_ speed: Float) {
        currentSpeed = speed
        player.rate = speed
        let label = speed == 1.0 ? "Speed (1x)" : "Speed (\(speed)x)"
        configureTextButton(speedButton, icon: "speedometer", title: label)
    }

    // MARK: - Time

    private func checkWatchedThreshold(at seconds: Double) {
        guard !hasReachedWatchedThreshold, seconds.isFinite, seconds >= watchedThreshold else { return }
        hasReachedWatchedThreshold = true
        onWatchedReached?()
    }

    private func updateTime(_ time: CMTime) {
        guard !isSeeking else { return }
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite else { return }
        seekBar.value = Float(seconds)
        currentTimeLabel.text = formatTime(seconds)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Picker Panel

    private func showPickerPanel(title: String, items: [PickerItem]) {
        let panel = PickerPanelView(title: title, items: items) { }
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        panel.alpha = 0
        UIView.animate(withDuration: 0.2) { panel.alpha = 1 }
    }
}

// MARK: - Gesture Delegate

extension CustomPlayerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchView = touch.view else { return true }
        if touchView is UIButton || touchView is UISlider { return false }
        // Check if touch hits any interactive control
        let point = touch.location(in: controlsContainer)
        if let hit = controlsContainer.hitTest(point, with: nil),
           hit is UIButton || hit is UISlider {
            return false
        }
        return true
    }
}

// MARK: - Picker Data

struct PickerItem {
    let title: String
    let isSelected: Bool
    let action: () -> Void
}

// MARK: - Picker Panel View

class PickerPanelView: UIView {
    private let onDismiss: () -> Void

    private let items: [PickerItem]
    private weak var tableView: UITableView?

    init(title: String, items: [PickerItem], onDismiss: @escaping () -> Void) {
        self.items = items
        self.onDismiss = onDismiss
        super.init(frame: .zero)

        // Dimmed background
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        let tapBg = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        addGestureRecognizer(tapBg)

        // Panel container
        let panel = UIView()
        panel.backgroundColor = UIColor(white: 0.15, alpha: 1)
        panel.layer.cornerRadius = 12
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 280),
            panel.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, constant: -40)
        ])

        // Block tap from dismissing when tapping inside panel
        let blockTap = UITapGestureRecognizer()
        blockTap.cancelsTouchesInView = false
        panel.addGestureRecognizer(blockTap)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16)
        ])

        // Scrollable list — self is the dataSource/delegate
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorColor = UIColor.white.withAlphaComponent(0.1)
        tv.showsVerticalScrollIndicator = true
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(PickerCell.self, forCellReuseIdentifier: "cell")
        tv.dataSource = self
        tv.delegate = self
        panel.addSubview(tv)
        self.tableView = tv

        let tableHeight = min(CGFloat(items.count) * 44, 340)
        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tv.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            tv.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -8),
            tv.heightAnchor.constraint(equalToConstant: tableHeight)
        ])

        tv.reloadData()
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func dismiss() {
        UIView.animate(withDuration: 0.15, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
            self.onDismiss()
        }
    }
}

extension PickerPanelView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! PickerCell
        let item = items[indexPath.row]
        cell.configure(title: item.title, isSelected: item.isSelected)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        items[indexPath.row].action()
        dismiss()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 44 }
}

// MARK: - Picker Cell

class PickerCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        textLabel?.textColor = .white
        textLabel?.font = .systemFont(ofSize: 15)
        selectionStyle = .none
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, isSelected: Bool) {
        textLabel?.text = title
        accessoryType = isSelected ? .checkmark : .none
        tintColor = .white
        textLabel?.textColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.8)
    }
}
