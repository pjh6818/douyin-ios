import SwiftUI
import WebKit

struct DouyinWebView: UIViewRepresentable {
    let viewModel: DouyinPlayerViewModel

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        let wv = viewModel.createWebView(coordinator: context.coordinator)
        context.coordinator.observe(wv)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
