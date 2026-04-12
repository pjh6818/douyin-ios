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
        let source = dict["source"] ?? ""

        switch type {
        case "visibleVideo":
            os_log("[DouyinPlayer] [%{public}s] 영상 감지", source)
            if let data = value.data(using: .utf8),
               let info = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               let url = info["url"] {
                viewModel.replaceWithVisibleVideo(url, title: info["desc"])
            } else {
                viewModel.replaceWithVisibleVideo(value)
            }
        case "videoInfoList":
            if let data = value.data(using: .utf8),
               let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                if viewModel.prefetchState != .idle {
                    os_log("[DouyinPlayer] [%{public}s] 영상 %d개 수신 → 큐에 추가", source, items.count)
                    viewModel.storeVideoInfoList(items)
                } else {
                    os_log("[DouyinPlayer] [%{public}s] 영상 %d개 수신 → 프리페치 미활성, 무시", source, items.count)
                }
            }
        case "prefetchStatus":
            os_log("[DouyinPlayer] [%{public}s] 프리페치 상태: %{public}s", source, value)
            if !value.hasPrefix("fetched_") {
                viewModel.handlePrefetchFailure()
            }
        case "urlChanged":
            os_log("[DouyinPlayer] URL 변경: %{public}s", value.prefix(100).description)
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
        webView.evaluateJavaScript(DouyinJavaScript.networkInterceptScript)
        webView.evaluateJavaScript(DouyinJavaScript.videoInterceptScript)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let mimeType = navigationResponse.response.mimeType,
           (mimeType.hasPrefix("video/") || mimeType.contains("mpegURL")),
           let url = navigationResponse.response.url?.absoluteString {
            os_log("[DouyinPlayer] [Layer5:mime] 영상 MIME 감지: %{public}s — %{public}s", mimeType, url.prefix(100).description)
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
