// DouyinPlayer.swift
// WKWebView로 Douyin 페이지를 탐색하다가 영상 클릭 시 AVPlayer로 재생
//
// 사용법:
//   DouyinBrowserView()

import SwiftUI
import WebKit
import AVKit
import Combine
import os

// MARK: - Main View

struct DouyinBrowserView: View {
    @StateObject private var browser = DouyinBrowser()

    private var isPlaying: Bool { browser.player != nil }

    var body: some View {
        ZStack {
            // 웹뷰 + 하단 내비게이션 바
            VStack(spacing: 0) {
                DouyinWebView(browser: browser)

                // 하단 브라우저 컨트롤
                browserToolbar
            }
            .opacity(isPlaying ? 0 : 1)

            // 영상 재생 화면
            if let player = browser.player {
                ZStack(alignment: .topLeading) {
                    Color.black.ignoresSafeArea()

                    VideoPlayer(player: player)
                        .ignoresSafeArea()

                    // 닫기 버튼
                    Button {
                        browser.dismissPlayer()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .padding(.top, 60)
                    .padding(.leading, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Browser Toolbar

    private var browserToolbar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 24) {
                // 뒤로
                Button { browser.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                }
                .disabled(!browser.canGoBack)

                // 앞으로
                Button { browser.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                }
                .disabled(!browser.canGoForward)

                // 새로고침 / 로딩 중지
                Button {
                    if browser.isLoading {
                        browser.stopLoading()
                    } else {
                        browser.reload()
                    }
                } label: {
                    Image(systemName: browser.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                }

                // URL 표시
                Text(browser.displayURL)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                // AVPlayer로 재생
                Button { browser.startPlayback() } label: {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(browser.extractedVideoURL != nil ? .blue : .gray)
                }
                .disabled(browser.extractedVideoURL == nil)

                // 홈 (정선 페이지)
                Button { browser.goHome() } label: {
                    Image(systemName: "house")
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }
}

// MARK: - WKWebView Wrapper

struct DouyinWebView: UIViewRepresentable {
    let browser: DouyinBrowser

    func makeUIView(context: Context) -> WKWebView {
        return browser.setupWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Browser / Coordinator

class DouyinBrowser: NSObject, ObservableObject {
    @Published var player: AVPlayer?
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var displayURL = ""
    /// 추출된 영상 URL (재생 대기 상태)
    @Published var extractedVideoURL: String?

    private var webView: WKWebView?
    private var observations: [NSKeyValueObservation] = []

    static let homeURL = URL(string: "https://www.douyin.com/jingxuan")!

    func setupWebView() -> WKWebView {
        if let existing = webView { return existing }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all

        let controller = WKUserContentController()
        controller.add(self, name: "douyin")
        controller.addUserScript(WKUserScript(
            source: Self.videoInterceptScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        ))
        config.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        // KVO로 웹뷰 상태 관찰
        observations = [
            wv.observe(\.canGoBack) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.canGoBack = wv.canGoBack }
            },
            wv.observe(\.canGoForward) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.canGoForward = wv.canGoForward }
            },
            wv.observe(\.isLoading) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.isLoading = wv.isLoading }
            },
            wv.observe(\.url) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.displayURL = wv.url?.host ?? ""
                }
            },
        ]

        wv.load(URLRequest(url: Self.homeURL))
        self.webView = wv
        return wv
    }

    // MARK: - Navigation Actions

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stopLoading() { webView?.stopLoading() }
    func goHome() { webView?.load(URLRequest(url: Self.homeURL)) }

    func dismissPlayer() {
        player?.pause()
        player = nil
        webView?.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause())")
    }

    /// 버튼으로 호출 — 추출된 URL을 AVPlayer로 재생
    func startPlayback() {
        guard let urlString = extractedVideoURL,
              let url = URL(string: urlString) else { return }

        os_log("[DouyinPlayer] Playing: %{public}s", urlString)

        let headers = ["Referer": "https://www.douyin.com/"]
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        if let existing = player {
            existing.replaceCurrentItem(with: item)
            existing.play()
        } else {
            player = AVPlayer(playerItem: item)
            player?.play()
        }
    }

    /// JS에서 영상 URL을 받으면 저장만 (자동 재생 안 함)
    private func storeVideoURL(_ urlString: String) {
        let cleaned = urlString
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "/playwm/", with: "/play/")

        guard let _ = URL(string: cleaned) else { return }

        os_log("[DouyinPlayer] Video ready: %{public}s", String(cleaned.prefix(120)))

        DispatchQueue.main.async {
            self.extractedVideoURL = cleaned
        }
    }

    // MARK: - JavaScript

    private static let videoInterceptScript = """
    (function() {
        if (window.__douyinInterceptInstalled) return;
        window.__douyinInterceptInstalled = true;

        var lastSentURL = '';

        function post(type, value) {
            try { window.webkit.messageHandlers.douyin.postMessage({type: type, value: value}); } catch(e) {}
        }

        function isRealVideoURL(url) {
            if (!url || url.length < 30) return false;
            if (url.startsWith('blob:')) return false;
            return url.includes('douyinvod') || url.includes('video_id=') ||
                   url.includes('tos-cn-ve') || url.includes('bytecdn') ||
                   url.includes('zjcdn.com') || url.includes('/video/tos/');
        }

        function sendURL(src, source) {
            if (isRealVideoURL(src) && src !== lastSentURL) {
                lastSentURL = src;
                post(source, src);
                return true;
            }
            return false;
        }

        // --- 1. video 요소에서 직접 추출 ---

        function extractFromVideos() {
            var videos = document.querySelectorAll('video');
            for (var i = 0; i < videos.length; i++) {
                var v = videos[i];
                var src = v.src || '';
                if (!src && v.querySelector('source')) {
                    src = v.querySelector('source').src || '';
                }
                if (sendURL(src, 'videoSrc')) return true;
            }
            return false;
        }

        function hookVideoEvents(video) {
            if (video.__douyinEvtHooked) return;
            video.__douyinEvtHooked = true;
            video.addEventListener('play', function() { setTimeout(extractFromVideos, 200); });
            video.addEventListener('loadeddata', function() { setTimeout(extractFromVideos, 200); });
        }

        // --- 2. SSR 데이터에서 추출 ---

        function findPlayAddr(obj, depth) {
            if (!obj || depth > 8) return null;
            if (typeof obj !== 'object') return null;
            if (obj.play_addr && obj.play_addr.url_list && obj.play_addr.url_list.length > 0) {
                return obj.play_addr.url_list[0];
            }
            if (Array.isArray(obj)) {
                for (var i = 0; i < Math.min(obj.length, 20); i++) {
                    var r = findPlayAddr(obj[i], depth + 1);
                    if (r) return r;
                }
            } else {
                for (var key in obj) {
                    if (!obj.hasOwnProperty(key)) continue;
                    var r = findPlayAddr(obj[key], depth + 1);
                    if (r) return r;
                }
            }
            return null;
        }

        function extractFromSSR() {
            try {
                if (window._ROUTER_DATA) {
                    var url = findPlayAddr(window._ROUTER_DATA, 0);
                    if (sendURL(url, 'ssrData')) return true;
                }
            } catch(e) {}
            try {
                var el = document.getElementById('RENDER_DATA');
                if (el) {
                    var data = JSON.parse(decodeURIComponent(el.textContent));
                    var url = findPlayAddr(data, 0);
                    if (sendURL(url, 'ssrData')) return true;
                }
            } catch(e) {}
            return false;
        }

        // --- 3. XHR/fetch 인터셉트 (추천 피드 등 blob: URL 페이지 대응) ---

        function extractURLsFromText(text) {
            try {
                var obj = JSON.parse(text);
                var url = findPlayAddr(obj, 0);
                if (url) sendURL(url, 'apiIntercept');
            } catch(e) {}
        }

        var origFetch = window.fetch;
        window.fetch = function() {
            var url = arguments[0];
            if (typeof url === 'string') {
                return origFetch.apply(this, arguments).then(function(response) {
                    var clone = response.clone();
                    clone.text().then(function(text) {
                        if (text.includes('play_addr')) {
                            extractURLsFromText(text);
                        }
                    }).catch(function(){});
                    return response;
                });
            }
            return origFetch.apply(this, arguments);
        };

        var origXHROpen = XMLHttpRequest.prototype.open;
        var origXHRSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(method, url) {
            this.__douyinURL = url;
            return origXHROpen.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function() {
            var xhr = this;
            xhr.addEventListener('load', function() {
                try {
                    var text = xhr.responseText;
                    if (text && text.includes('play_addr')) {
                        extractURLsFromText(text);
                    }
                } catch(e) {}
            });
            return origXHRSend.apply(this, arguments);
        };

        // --- 4. DOM 감시 ---

        document.querySelectorAll('video').forEach(hookVideoEvents);

        var videoObserver = new MutationObserver(function(mutations) {
            for (var i = 0; i < mutations.length; i++) {
                var mut = mutations[i];
                for (var j = 0; j < mut.addedNodes.length; j++) {
                    var node = mut.addedNodes[j];
                    if (node.nodeName === 'VIDEO') {
                        hookVideoEvents(node);
                        setTimeout(extractFromVideos, 300);
                    } else if (node.querySelectorAll) {
                        node.querySelectorAll('video').forEach(hookVideoEvents);
                        if (node.querySelectorAll('video').length > 0) {
                            setTimeout(extractFromVideos, 300);
                        }
                    }
                }
                if (mut.type === 'attributes' && mut.target.nodeName === 'VIDEO') {
                    setTimeout(extractFromVideos, 200);
                }
            }
        });
        videoObserver.observe(document.documentElement, {
            childList: true, subtree: true, attributes: true, attributeFilter: ['src']
        });

        // --- 5. URL 변경 + 주기적 재시도 ---

        var lastURL = location.href;
        setInterval(function() {
            if (location.href !== lastURL) {
                lastURL = location.href;
                setTimeout(function() {
                    document.querySelectorAll('video').forEach(hookVideoEvents);
                    extractFromVideos() || extractFromSSR();
                }, 800);
            }
        }, 300);

        setTimeout(function() {
            extractFromVideos() || extractFromSSR();
        }, 1500);
    })();
    """
}

// MARK: - WKScriptMessageHandler

extension DouyinBrowser: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: String],
              let type = dict["type"],
              let value = dict["value"] else { return }

        os_log("[DouyinPlayer] JS message: %{public}s = %{public}s", type, String(value.prefix(150)))

        switch type {
        case "videoSrc", "ssrData", "apiIntercept", "apiRegex":
            storeVideoURL(value)
        default:
            break
        }
    }
}

// MARK: - WKNavigationDelegate

extension DouyinBrowser: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("[DouyinPlayer] Page loaded: %{public}s", webView.url?.absoluteString ?? "nil")
        webView.evaluateJavaScript(Self.videoInterceptScript)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let mimeType = navigationResponse.response.mimeType,
           (mimeType.hasPrefix("video/") || mimeType.contains("mpegURL")),
           let url = navigationResponse.response.url?.absoluteString {
            os_log("[DouyinPlayer] Video MIME detected: %{public}s", mimeType)
            storeVideoURL(url)
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        os_log("[DouyinPlayer] Navigation failed: %{public}s", error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        os_log("[DouyinPlayer] Provisional navigation failed: %{public}s", error.localizedDescription)
    }
}
