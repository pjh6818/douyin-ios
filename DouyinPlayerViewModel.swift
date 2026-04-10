import SwiftUI
import WebKit
import AVKit
import os

@Observable
final class DouyinPlayerViewModel {
    enum PrefetchState { case idle, scrolling, waiting, failed }

    var player: AVPlayer?
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var displayURL = ""
    var extractedVideoURL: String?
    var videoURLs: [String] = []
    var videoTitles: [String: String] = [:]
    var hasVideoContent = false
    var prefetchState: PrefetchState = .idle
    private(set) var pendingAutoPlayNext = false
    private var prefetchTimer: Timer?

    var nextVideoURL: String? {
        guard let current = extractedVideoURL,
              let idx = videoURLs.firstIndex(of: current),
              idx + 1 < videoURLs.count else { return nil }
        return videoURLs[idx + 1]
    }

    var previousVideoURL: String? {
        guard let current = extractedVideoURL,
              let idx = videoURLs.firstIndex(of: current),
              idx > 0 else { return nil }
        return videoURLs[idx - 1]
    }

    var currentIndex: Int? {
        guard let current = extractedVideoURL,
              let idx = videoURLs.firstIndex(of: current) else { return nil }
        return idx + 1
    }

    var currentTitle: String? {
        guard let url = extractedVideoURL else { return nil }
        return videoTitles[url]
    }

    var isPlaying: Bool { player != nil }

    private(set) var webView: WKWebView?

    static let homeURL = URL(string: "https://www.douyin.com/jingxuan")!

    // MARK: - WebView Setup

    func createWebView(coordinator: WebViewCoordinator) -> WKWebView {
        if let existing = webView { return existing }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        controller.add(coordinator, name: "douyin")
        controller.addUserScript(WKUserScript(
            source: DouyinJavaScript.networkInterceptScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        controller.addUserScript(WKUserScript(
            source: DouyinJavaScript.videoInterceptScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        ))
        config.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        wv.load(URLRequest(url: Self.homeURL))
        self.webView = wv
        return wv
    }

    // MARK: - Navigation

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { clearVideoURL(); webView?.reload() }
    func stopLoading() { webView?.stopLoading() }
    func goHome() { clearVideoURL(); webView?.load(URLRequest(url: Self.homeURL)) }

    // MARK: - Player

    func dismissPlayer() {
        player?.pause()
        player = nil
        webView?.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause())")
    }

    func startPlayback() {
        webView?.evaluateJavaScript(DouyinJavaScript.getCurrentVideoScript) { [weak self] result, error in
            guard let self else { return }

            let urlString: String
            if let jsURL = result as? String {
                self.storeVideoURL(jsURL)
                urlString = self.extractedVideoURL ?? jsURL
            } else if let cached = self.extractedVideoURL {
                urlString = cached
            } else {
                os_log("[DouyinPlayer] No video URL available")
                return
            }

            if let idx = self.videoURLs.firstIndex(of: urlString) {
                os_log("[DouyinPlayer] 큐 위치: %d/%d", idx + 1, self.videoURLs.count)
            }

            self.extractedVideoURL = urlString
            self.playURL(urlString)
        }
    }

    func playNext() {
        if let next = nextVideoURL {
            extractedVideoURL = next
            playURL(next)
        } else {
            pendingAutoPlayNext = true
            triggerPrefetch()
        }
    }

    func playPrevious() {
        guard let prev = previousVideoURL else { return }
        extractedVideoURL = prev
        playURL(prev)
    }

    // MARK: - Playback

    private func playURL(_ urlString: String) {
        guard var url = URL(string: urlString) else { return }

        webView?.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }

            if urlString.contains("tk=webid"), !urlString.contains("&webid=") {
                if let webidCookie = cookies.first(where: { $0.name == "s_v_web_id" || $0.name == "webid" }) {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    var items = components?.queryItems ?? []
                    items.append(URLQueryItem(name: "webid", value: webidCookie.value))
                    components?.queryItems = items
                    if let newURL = components?.url { url = newURL }
                }
            }

            os_log("[DouyinPlayer] Playing: %{public}s", url.absoluteString.prefix(200).description)

            let headers = ["Referer": "https://www.douyin.com/"]
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            let item = AVPlayerItem(asset: asset)
            DispatchQueue.main.async {
                if let existing = self.player {
                    existing.replaceCurrentItem(with: item)
                    existing.play()
                } else {
                    self.player = AVPlayer(playerItem: item)
                    self.player?.play()
                }
                self.checkProactivePrefetch()
            }
        }
    }

    // MARK: - Video URL Extraction

    func clearVideoURL() {
        extractedVideoURL = nil
        videoURLs = []
        videoTitles = [:]
        hasVideoContent = false
        prefetchState = .idle
        prefetchTimer?.invalidate()
        prefetchTimer = nil
        pendingAutoPlayNext = false
    }

    func replaceWithVisibleVideo(_ urlString: String, title: String? = nil) {
        guard let url = cleanURL(urlString) else { return }
        videoURLs = [url]
        if let title, !title.isEmpty { videoTitles[url] = title }
        extractedVideoURL = url
        hasVideoContent = true
    }

    func storeVideoURL(_ urlString: String) {
        guard let url = cleanURL(urlString) else { return }
        if !videoURLs.contains(url) {
            videoURLs.append(url)
            resolvePendingPrefetch()
        }
        if !isPlaying { extractedVideoURL = url }
        hasVideoContent = true
    }

    func storeVideoInfoList(_ items: [[String: String]]) {
        var added = 0
        for item in items {
            guard let urlString = item["url"], let cleaned = cleanURL(urlString) else { continue }
            if !videoURLs.contains(cleaned) {
                videoURLs.append(cleaned)
                added += 1
            }
            if let desc = item["desc"], !desc.isEmpty {
                videoTitles[cleaned] = desc
            }
        }
        if added > 0 {
            hasVideoContent = true
            resolvePendingPrefetch()
        }
    }

    private func cleanURL(_ urlString: String) -> String? {
        let cleaned = urlString
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "/playwm/", with: "/play/")
        guard URL(string: cleaned) != nil else { return nil }
        return cleaned
    }

    // MARK: - Prefetch

    func triggerPrefetch() {
        guard prefetchState == .idle else { return }

        prefetchState = .scrolling
        os_log("[DouyinPlayer] Prefetch: 다음 영상 로드 트리거")

        webView?.evaluateJavaScript(DouyinJavaScript.scrollToLoadMoreScript) { [weak self] _, error in
            guard let self else { return }
            if let error {
                os_log("[DouyinPlayer] Prefetch 스크롤 에러: %{public}s", error.localizedDescription)
                self.prefetchState = .failed
                return
            }
            if self.prefetchState == .scrolling {
                self.prefetchState = .waiting
            }
        }

        prefetchTimer?.invalidate()
        prefetchTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            guard let self, self.prefetchState != .idle else { return }
            os_log("[DouyinPlayer] Prefetch 타임아웃")
            self.prefetchState = .failed
            self.pendingAutoPlayNext = false
        }
    }

    func handlePrefetchFailure() {
        prefetchState = .failed
        pendingAutoPlayNext = false
    }

    private func resolvePendingPrefetch() {
        guard prefetchState == .scrolling || prefetchState == .waiting else { return }
        prefetchState = .idle
        prefetchTimer?.invalidate()
        prefetchTimer = nil

        if pendingAutoPlayNext {
            pendingAutoPlayNext = false
            playNext()
        }
    }

    private func checkProactivePrefetch() {
        guard let current = extractedVideoURL,
              let idx = videoURLs.firstIndex(of: current) else { return }
        let remaining = videoURLs.count - idx - 1
        if remaining <= 2 && prefetchState == .idle {
            os_log("[DouyinPlayer] 프로액티브 프리페치: 남은 영상 %d개", remaining)
            triggerPrefetch()
        }
    }

    // MARK: - KVO Sync

    func syncState(from webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        displayURL = webView.url?.host ?? ""
    }
}
