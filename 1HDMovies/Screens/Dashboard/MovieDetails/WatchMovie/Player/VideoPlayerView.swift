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

        let playerVC = CustomPlayerViewController(player: player, subtitles: subtitles, onClose: onClose)
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
    private let onClose: () -> Void

    // Video layer
    private var playerLayer: AVPlayerLayer!

    // Controls
    private let controlsContainer = UIView()
    private let topBar = UIView()
    private let playPauseButton = UIButton(type: .system)
    private let seekBar = UISlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let rewindButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)

    // Bottom options row (below seek bar)
    private let subtitlesButton = UIButton(type: .system)
    private let speedButton = UIButton(type: .system)

    // Subtitles
    private let subtitleLabel = UILabel()
    private var cues: [SubtitleCue] = []
    private var subtitlesEnabled = true
    private var selectedTrack: SubtitleTrack?
    private var timeObserver: Any?

    // Speed
    private var currentSpeed: Float = 1.0
    private let speeds: [Float] = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]

    // Controls visibility
    private var controlsVisible = true
    private var hideControlsTask: Task<Void, Never>?
    private var isSeeking = false

    // Observations
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?

    init(player: AVPlayer, subtitles: [SubtitleTrack], onClose: @escaping () -> Void) {
        self.player = player
        self.subtitles = subtitles
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
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

        // Center controls
        let centerStack = UIStackView(arrangedSubviews: [rewindButton, playPauseButton, forwardButton])
        centerStack.axis = .horizontal
        centerStack.spacing = 48
        centerStack.alignment = .center
        centerStack.translatesAutoresizingMaskIntoConstraints = false

        configureSymbolButton(rewindButton, systemName: "gobackward.10", size: 28)
        configureSymbolButton(playPauseButton, systemName: "pause.fill", size: 36)
        configureSymbolButton(forwardButton, systemName: "goforward.10", size: 28)

        rewindButton.addTarget(self, action: #selector(rewindTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)

        controlsContainer.addSubview(centerStack)
        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor)
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
            optionsRow.heightAnchor.constraint(equalToConstant: 32)
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

        let optionsStack = UIStackView(arrangedSubviews: [subtitlesButton, speedButton])
        optionsStack.axis = .horizontal
        optionsStack.spacing = 24
        optionsStack.alignment = .center
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsRow.addSubview(optionsStack)

        NSLayoutConstraint.activate([
            optionsStack.centerXAnchor.constraint(equalTo: optionsRow.centerXAnchor),
            optionsStack.centerYAnchor.constraint(equalTo: optionsRow.centerYAnchor),
            subtitlesButton.heightAnchor.constraint(equalToConstant: 32),
            speedButton.heightAnchor.constraint(equalToConstant: 32)
        ])
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleControls))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupObservers() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateTime(time)
            self?.updateSubtitle(at: time.seconds)
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                let isPlaying = player.timeControlStatus == .playing
                let name = isPlaying ? "pause.fill" : "play.fill"
                let cfg = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
                self?.playPauseButton.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
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

    @objc private func playPauseTapped() {
        if player.timeControlStatus == .playing { player.pause() } else { player.play() }
        scheduleHideControls()
    }

    @objc private func rewindTapped() {
        let t = CMTimeGetSeconds(player.currentTime())
        player.seek(to: CMTime(seconds: max(0, t - 10), preferredTimescale: 1))
        scheduleHideControls()
    }

    @objc private func forwardTapped() {
        let t = CMTimeGetSeconds(player.currentTime())
        let d = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        player.seek(to: CMTime(seconds: min(d, t + 10), preferredTimescale: 1))
        scheduleHideControls()
    }

    @objc private func seekStarted() { isSeeking = true }

    @objc private func seekChanged() {
        let time = CMTime(seconds: Double(seekBar.value), preferredTimescale: 1)
        currentTimeLabel.text = formatTime(Double(seekBar.value))
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    @objc private func seekEnded() {
        isSeeking = false
        scheduleHideControls()
    }

    @objc private func toggleControls() {
        controlsVisible.toggle()
        UIView.animate(withDuration: 0.25) {
            self.controlsContainer.alpha = self.controlsVisible ? 1 : 0
        }
        if controlsVisible { scheduleHideControls() }
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
        scheduleHideControls()
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
        scheduleHideControls()
    }

    private func setSpeed(_ speed: Float) {
        currentSpeed = speed
        player.rate = speed
        let label = speed == 1.0 ? "Speed (1x)" : "Speed (\(speed)x)"
        configureTextButton(speedButton, icon: "speedometer", title: label)
    }

    // MARK: - Time

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
        let panel = PickerPanelView(title: title, items: items) { [weak self] in
            self?.scheduleHideControls()
        }
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
