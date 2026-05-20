import SwiftUI
import WebKit
import os

private let log = Logger(subsystem: "com.dajver.one.hd", category: "StreamDetector")

struct WatchMovieView: View {
    let movieUrl: String
    var episodes: [MovieEpisodesDataModel] = []
    var currentEpisodeIndex: Int = 0

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = WatchMovieViewModel()
    @State private var detectedStreamUrl: String?
    @State private var detectedSubtitles: [SubtitleTrack] = []
    @State private var activeEpisodeIndex: Int = 0
    @State private var activeMovieUrl: String = ""
    @State private var streamKey: UUID = UUID()

    private var isPlayerShowing: Bool { detectedStreamUrl != nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let streamUrl = detectedStreamUrl {
                VideoPlayerView(
                    url: streamUrl,
                    referer: viewModel.embedUrl ?? activeMovieUrl,
                    subtitles: detectedSubtitles,
                    episodes: episodes,
                    currentEpisodeIndex: activeEpisodeIndex,
                    servers: viewModel.servers,
                    selectedServer: viewModel.selectedServer,
                    onClose: { dismiss() },
                    onEpisodeChange: { index in
                        loadEpisode(at: index)
                    },
                    onServerChange: { server in
                        switchServer(server)
                    }
                )
                .ignoresSafeArea()
                .id(streamKey)
            } else {
                if !viewModel.isLoading {
                    StreamDetectorWebView(
                        url: viewModel.embedUrl ?? activeMovieUrl,
                        referer: activeMovieUrl,
                        onStreamDetected: { streamUrl, subtitles in
                            if detectedStreamUrl == nil {
                                detectedSubtitles = subtitles
                                detectedStreamUrl = streamUrl
                            }
                        }
                    )
                    .frame(width: 0, height: 0)
                    .opacity(0)
                }

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(isPlayerShowing)
        .onAppear {
            activeEpisodeIndex = currentEpisodeIndex
            activeMovieUrl = movieUrl
        }
        .task {
            await viewModel.fetchEmbedUrl(watchUrl: movieUrl)
        }
    }

    private func loadEpisode(at index: Int) {
        guard index >= 0, index < episodes.count else { return }
        activeEpisodeIndex = index
        activeMovieUrl = episodes[index].link
        resetStream()
        Task {
            await viewModel.fetchEmbedUrl(watchUrl: episodes[index].link)
        }
    }

    private func switchServer(_ server: ServerOption) {
        viewModel.selectServer(server)
        resetStream()
    }

    private func resetStream() {
        detectedStreamUrl = nil
        detectedSubtitles = []
        streamKey = UUID()
        viewModel.isLoading = false
    }
}

struct StreamDetectorWebView: UIViewRepresentable {
    let url: String
    let referer: String
    let onStreamDetected: (String, [SubtitleTrack]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStreamDetected: onStreamDetected)
    }

    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "streamDetector")

        let interceptScript = WKUserScript(source: Self.interceptJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(interceptScript)

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = preferences
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = Config.userAgent
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let requestUrl = URL(string: url) else { return }
        if webView.url == nil {
            var request = URLRequest(url: requestUrl)
            request.setValue(referer, forHTTPHeaderField: "Referer")
            webView.load(request)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "streamDetector")
    }

    static let interceptJS = """
    (function() {
        var reportedStreams = {};
        var reportedSubs = {};

        function reportStream(url) {
            if (url && url.indexOf('.m3u8') !== -1 && !reportedStreams[url]) {
                reportedStreams[url] = true;
                window.webkit.messageHandlers.streamDetector.postMessage(JSON.stringify({type: 'stream', url: url}));
            }
        }

        function reportSub(url, label, lang) {
            if (url && !reportedSubs[url]) {
                reportedSubs[url] = true;
                window.webkit.messageHandlers.streamDetector.postMessage(JSON.stringify({
                    type: 'subtitle', url: url, label: label || '', lang: lang || ''
                }));
            }
        }

        function scanForSubs(text) {
            try {
                // Try parsing as JSON and look for subtitle/track arrays
                var obj = (typeof text === 'string') ? JSON.parse(text) : text;
                scanObject(obj);
            } catch(e) {}
        }

        function scanObject(obj) {
            if (!obj || typeof obj !== 'object') return;
            if (Array.isArray(obj)) {
                obj.forEach(function(item) { scanObject(item); });
                return;
            }
            // Look for subtitle-like objects: {file/url/src: "...", label/language: "...", kind: "captions/subtitles"}
            var subUrl = obj.file || obj.url || obj.src || '';
            var kind = (obj.kind || '').toLowerCase();
            var label = obj.label || obj.language || obj.lang || '';
            if (subUrl && (kind === 'captions' || kind === 'subtitles' ||
                subUrl.indexOf('.vtt') !== -1 || subUrl.indexOf('.srt') !== -1)) {
                reportSub(subUrl, label, obj.language || obj.lang || '');
            }
            // Recurse into known container keys
            ['tracks', 'subtitles', 'captions', 'subs', 'textTracks', 'sources'].forEach(function(key) {
                if (obj[key]) scanObject(obj[key]);
            });
        }

        // Intercept XHR - both URL and response body
        var origOpen = XMLHttpRequest.prototype.open;
        var origSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(method, url) {
            this._interceptUrl = url;
            reportStream(url);
            if (url && (url.indexOf('.vtt') !== -1 || url.indexOf('.srt') !== -1)) {
                reportSub(url, '', '');
            }
            return origOpen.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function() {
            var xhr = this;
            xhr.addEventListener('load', function() {
                try {
                    var ct = xhr.getResponseHeader('content-type') || '';
                    if (ct.indexOf('json') !== -1 || (xhr._interceptUrl && xhr._interceptUrl.indexOf('json') !== -1)) {
                        scanForSubs(xhr.responseText);
                    }
                    // Also check if response text contains subtitle URLs
                    if (xhr.responseText) {
                        var vttMatches = xhr.responseText.match(/https?:[^"'\\s]+\\.vtt/g);
                        if (vttMatches) {
                            vttMatches.forEach(function(u) { reportSub(u, '', ''); });
                        }
                    }
                } catch(e) {}
            });
            return origSend.apply(this, arguments);
        };

        // Intercept fetch - both URL and response body
        var origFetch = window.fetch;
        window.fetch = function(input) {
            var url = (typeof input === 'string') ? input : (input && input.url ? input.url : '');
            reportStream(url);
            if (url && (url.indexOf('.vtt') !== -1 || url.indexOf('.srt') !== -1)) {
                reportSub(url, '', '');
            }
            return origFetch.apply(this, arguments).then(function(response) {
                var clone = response.clone();
                clone.text().then(function(text) {
                    try {
                        scanForSubs(text);
                        var vttMatches = text.match(/https?:[^"'\\s]+\\.vtt/g);
                        if (vttMatches) {
                            vttMatches.forEach(function(u) { reportSub(u, '', ''); });
                        }
                    } catch(e) {}
                }).catch(function(){});
                return response;
            });
        };

        // Intercept createElement for video/source/track
        var origCreateElement = document.createElement.bind(document);
        document.createElement = function(tag) {
            var el = origCreateElement(tag);
            var tagLower = tag.toLowerCase();
            if (tagLower === 'video' || tagLower === 'source') {
                var origSetAttr = el.setAttribute.bind(el);
                el.setAttribute = function(name, value) {
                    if (name === 'src') { reportStream(value); }
                    return origSetAttr(name, value);
                };
                var descriptor = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src') ||
                                 Object.getOwnPropertyDescriptor(HTMLSourceElement.prototype, 'src');
                if (descriptor && descriptor.set) {
                    var origSet = descriptor.set;
                    Object.defineProperty(el, 'src', {
                        set: function(v) { reportStream(v); return origSet.call(this, v); },
                        get: descriptor.get
                    });
                }
            }
            if (tagLower === 'track') {
                var origSetAttr2 = el.setAttribute.bind(el);
                el.setAttribute = function(name, value) {
                    if (name === 'src') { reportSub(value, '', ''); }
                    return origSetAttr2(name, value);
                };
            }
            return el;
        };

        // Periodic scan of DOM and player APIs
        function fullScan() {
            // Video sources
            document.querySelectorAll('video').forEach(function(v) {
                if (v.src) reportStream(v.src);
                v.querySelectorAll('source').forEach(function(s) {
                    if (s.src) reportStream(s.src);
                });
            });
            // Track elements
            document.querySelectorAll('track').forEach(function(t) {
                if (t.src) reportSub(t.src, t.label || '', t.srclang || '');
            });
            // JWPlayer
            if (typeof jwplayer !== 'undefined') {
                try {
                    var cfg = jwplayer().getConfig();
                    if (cfg && cfg.tracks) scanObject({tracks: cfg.tracks});
                    var playlist = jwplayer().getPlaylist();
                    if (playlist) playlist.forEach(function(item) {
                        if (item.tracks) scanObject({tracks: item.tracks});
                    });
                } catch(e) {}
            }
            // Video.js
            var vjsEl = document.querySelector('.video-js');
            if (vjsEl && vjsEl.player) {
                try {
                    var tt = vjsEl.player.textTracks();
                    for (var i = 0; i < tt.length; i++) {
                        if (tt[i].src) reportSub(tt[i].src, tt[i].label || '', tt[i].language || '');
                    }
                } catch(e) {}
            }
            // Scan all script tags for VTT URLs
            document.querySelectorAll('script').forEach(function(s) {
                if (s.textContent) {
                    var matches = s.textContent.match(/https?:[^"'\\s]+\\.vtt/g);
                    if (matches) matches.forEach(function(u) {
                        reportSub(u.replace(/\\\\/g, ''), '', '');
                    });
                }
            });
        }

        var observer = new MutationObserver(function() { fullScan(); });
        observer.observe(document.documentElement, { childList: true, subtree: true });
        setInterval(fullScan, 2000);
    })();
    """

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onStreamDetected: (String, [SubtitleTrack]) -> Void
        weak var webView: WKWebView?
        private var hasDetectedStream = false
        private var sourceList: [String] = []
        private var subtitleList: [String: SubtitleTrack] = [:]
        private var debounceTask: Task<Void, Never>?

        init(onStreamDetected: @escaping (String, [SubtitleTrack]) -> Void) {
            self.onStreamDetected = onStreamDetected
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "streamDetector",
                  let jsonString = message.body as? String,
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String,
                  let url = json["url"] as? String else { return }

            log.info("JS message: type=\(type) url=\(url.prefix(100))")

            if type == "stream" {
                handleStreamUrl(url)
            } else if type == "subtitle" {
                let label = json["label"] as? String ?? ""
                let lang = json["lang"] as? String ?? ""
                log.info("Subtitle detected: label=\(label) lang=\(lang) url=\(url)")
                if subtitleList[url] == nil {
                    subtitleList[url] = SubtitleTrack(
                        label: label.isEmpty ? (lang.isEmpty ? "Unknown" : lang) : label,
                        url: url,
                        language: lang
                    )
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString, url.contains(".m3u8") {
                handleStreamUrl(url)
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let url = navigationResponse.response.url?.absoluteString, url.contains(".m3u8") {
                handleStreamUrl(url)
            }
            decisionHandler(.allow)
        }

        private func handleStreamUrl(_ url: String) {
            guard !hasDetectedStream else { return }
            if !sourceList.contains(url) {
                sourceList.append(url)
            }
            debounceTask?.cancel()
            debounceTask = Task { @MainActor in
                // Wait for subtitles to also be detected
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, !self.sourceList.isEmpty, !self.hasDetectedStream else { return }
                self.hasDetectedStream = true
                log.info("Final report: stream=\(self.sourceList.first!) subtitles=\(self.subtitleList.count)")
                self.onStreamDetected(self.sourceList.first!, Array(self.subtitleList.values))
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let autoPlayScript = """
            (function() {
                function tryPlay() {
                    if (typeof jwplayer !== 'undefined') {
                        try { jwplayer().play(); return true; } catch(e) {}
                    }
                    var vjsPlayer = document.querySelector('.video-js');
                    if (vjsPlayer && vjsPlayer.player) {
                        try { vjsPlayer.player.play(); return true; } catch(e) {}
                    }
                    var video = document.querySelector('video');
                    if (video) { video.play(); return true; }
                    var selectors = ['.jw-icon-playback', '.jw-display-icon-container', '.vjs-big-play-button', '[class*="play-btn"]', '[class*="playBtn"]', 'button[aria-label*="Play"]', '.play-button', '#play-btn'];
                    for (var i = 0; i < selectors.length; i++) {
                        var btn = document.querySelector(selectors[i]);
                        if (btn) { btn.click(); return true; }
                    }
                    return false;
                }
                setTimeout(tryPlay, 1000);
                setTimeout(tryPlay, 3000);
                setTimeout(tryPlay, 5000);
            })();
            """
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                webView.evaluateJavaScript(autoPlayScript, completionHandler: nil)
            }
        }
    }
}
