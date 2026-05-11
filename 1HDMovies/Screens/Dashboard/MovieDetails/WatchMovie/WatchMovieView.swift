import SwiftUI
import WebKit

struct WatchMovieView: View {
    let movieUrl: String
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = WatchMovieViewModel()
    @State private var detectedStreamUrl: String?

    private var isPlayerShowing: Bool { detectedStreamUrl != nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let streamUrl = detectedStreamUrl {
                VideoPlayerView(
                    url: streamUrl,
                    referer: viewModel.embedUrl ?? movieUrl,
                    onClose: { dismiss() }
                )
                .ignoresSafeArea()
            } else {
                if !viewModel.isLoading {
                    StreamDetectorWebView(
                        url: viewModel.embedUrl ?? movieUrl,
                        referer: movieUrl,
                        onStreamDetected: { streamUrl in
                            if detectedStreamUrl == nil {
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
        .task {
            await viewModel.fetchEmbedUrl(watchUrl: movieUrl)
        }
    }
}

struct StreamDetectorWebView: UIViewRepresentable {
    let url: String
    let referer: String
    let onStreamDetected: (String) -> Void

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
        function reportUrl(url) {
            if (url && url.indexOf('.m3u8') !== -1) {
                window.webkit.messageHandlers.streamDetector.postMessage(url);
            }
        }

        var origOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
            reportUrl(url);
            return origOpen.apply(this, arguments);
        };

        var origFetch = window.fetch;
        window.fetch = function(input) {
            var url = (typeof input === 'string') ? input : (input && input.url ? input.url : '');
            reportUrl(url);
            return origFetch.apply(this, arguments);
        };

        var origCreateElement = document.createElement.bind(document);
        document.createElement = function(tag) {
            var el = origCreateElement(tag);
            if (tag.toLowerCase() === 'video' || tag.toLowerCase() === 'source') {
                var origSetAttr = el.setAttribute.bind(el);
                el.setAttribute = function(name, value) {
                    if (name === 'src') { reportUrl(value); }
                    return origSetAttr(name, value);
                };
                var descriptor = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src') ||
                                 Object.getOwnPropertyDescriptor(HTMLSourceElement.prototype, 'src');
                if (descriptor && descriptor.set) {
                    var origSet = descriptor.set;
                    Object.defineProperty(el, 'src', {
                        set: function(v) { reportUrl(v); return origSet.call(this, v); },
                        get: descriptor.get
                    });
                }
            }
            return el;
        };

        function checkVideos() {
            document.querySelectorAll('video').forEach(function(v) {
                if (v.src) reportUrl(v.src);
                v.querySelectorAll('source').forEach(function(s) {
                    if (s.src) reportUrl(s.src);
                });
            });
        }
        var observer = new MutationObserver(function(mutations) {
            checkVideos();
            mutations.forEach(function(m) {
                m.addedNodes.forEach(function(node) {
                    if (node.tagName === 'VIDEO' || node.tagName === 'SOURCE') {
                        if (node.src) reportUrl(node.src);
                    }
                    if (node.querySelectorAll) {
                        node.querySelectorAll('video, source').forEach(function(el) {
                            if (el.src) reportUrl(el.src);
                        });
                    }
                });
            });
        });
        observer.observe(document.documentElement, { childList: true, subtree: true });

        setInterval(checkVideos, 2000);
    })();
    """

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onStreamDetected: (String) -> Void
        weak var webView: WKWebView?
        private var hasDetectedStream = false
        private var sourceList: [String] = []
        private var debounceTask: Task<Void, Never>?

        init(onStreamDetected: @escaping (String) -> Void) {
            self.onStreamDetected = onStreamDetected
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "streamDetector",
                  let urlString = message.body as? String,
                  urlString.contains(".m3u8") else { return }
            handleStreamUrl(urlString)
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
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, !self.sourceList.isEmpty, !self.hasDetectedStream else { return }
                self.hasDetectedStream = true
                self.onStreamDetected(self.sourceList.first!)
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
