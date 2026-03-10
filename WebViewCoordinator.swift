import WebKit
import os

final class WebViewCoordinator: NSObject {
    let viewModel: DouyinPlayerViewModel
    private var observations: [NSKeyValueObservation] = []

    init(viewModel: DouyinPlayerViewModel) {
        self.viewModel = viewModel
    }

    func observe(_ webView: WKWebView) {
        observations = [
            webView.observe(\.canGoBack) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.viewModel.syncState(from: wv) }
            },
            webView.observe(\.canGoForward) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.viewModel.syncState(from: wv) }
            },
            webView.observe(\.isLoading) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.viewModel.syncState(from: wv) }
            },
            webView.observe(\.url) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.viewModel.syncState(from: wv) }
            },
        ]
    }
}

// MARK: - WKScriptMessageHandler

extension WebViewCoordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: String],
              let type = dict["type"],
              let value = dict["value"] else { return }

        os_log("[DouyinPlayer] JS message: %{public}s = %{public}s", type, String(value.prefix(150)))

        switch type {
        case "videoSrc", "ssrData", "apiIntercept", "apiRegex", "visibleVideo":
            viewModel.storeVideoURL(value)
        case "urlChanged":
            // In-page URL changed (e.g. Douyin SPA navigation) — reset stale URL
            viewModel.clearVideoURL()
        default:
            break
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebViewCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Clear stale video URL when navigating to a new page
        viewModel.clearVideoURL()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        os_log("[DouyinPlayer] Page loaded: %{public}s", webView.url?.absoluteString ?? "nil")
        webView.evaluateJavaScript(DouyinJavaScript.videoInterceptScript)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let mimeType = navigationResponse.response.mimeType,
           (mimeType.hasPrefix("video/") || mimeType.contains("mpegURL")),
           let url = navigationResponse.response.url?.absoluteString {
            os_log("[DouyinPlayer] Video MIME detected: %{public}s", mimeType)
            viewModel.storeVideoURL(url)
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
