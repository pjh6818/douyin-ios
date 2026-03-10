import SwiftUI
import WebKit
import AVKit
import os

@Observable
final class DouyinPlayerViewModel {
    var player: AVPlayer?
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var displayURL = ""
    var extractedVideoURL: String?
    /// True when the page is known to have video content (enables the play button).
    /// Set independently from `extractedVideoURL` so it persists through URL resets.
    var hasVideoContent = false

    var isPlaying: Bool { player != nil }

    private(set) var webView: WKWebView?

    static let homeURL = URL(string: "https://www.douyin.com/jingxuan")!

    // MARK: - WebView Setup

    func createWebView(coordinator: WebViewCoordinator) -> WKWebView {
        if let existing = webView { return existing }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all

        let controller = WKUserContentController()
        controller.add(coordinator, name: "douyin")
        controller.addUserScript(WKUserScript(
            source: DouyinJavaScript.videoInterceptScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        ))
        config.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

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

    func startPlayback() {
        // Real-time: ask JS for the currently visible video right now
        webView?.evaluateJavaScript(DouyinJavaScript.getCurrentVideoScript) { [weak self] result, error in
            guard let self else { return }

            let urlString: String
            if let jsURL = result as? String {
                // Use freshly extracted URL from the currently visible video
                self.storeVideoURL(jsURL)
                urlString = self.extractedVideoURL ?? jsURL
            } else if let cached = self.extractedVideoURL {
                // Fallback to previously cached URL
                urlString = cached
            } else {
                os_log("[DouyinPlayer] No video URL available")
                return
            }

            guard let url = URL(string: urlString) else { return }

            os_log("[DouyinPlayer] Playing: %{public}s", urlString)

            let headers = ["Referer": "https://www.douyin.com/"]
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            let item = AVPlayerItem(asset: asset)
            if let existing = self.player {
                existing.replaceCurrentItem(with: item)
                existing.play()
            } else {
                self.player = AVPlayer(playerItem: item)
                self.player?.play()
            }
        }
    }

    // MARK: - Video URL Extraction

    func clearVideoURL() {
        extractedVideoURL = nil
        hasVideoContent = false
    }

    func storeVideoURL(_ urlString: String) {
        let cleaned = urlString
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "/playwm/", with: "/play/")

        guard URL(string: cleaned) != nil else { return }

        os_log("[DouyinPlayer] Video ready: %{public}s", String(cleaned.prefix(120)))
        extractedVideoURL = cleaned
        hasVideoContent = true
    }

    // MARK: - KVO Sync

    func syncState(from webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        displayURL = webView.url?.host ?? ""
    }
}
