import SwiftUI
import AVKit

struct DouyinBrowserView: View {
    @State private var viewModel = DouyinPlayerViewModel()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                DouyinWebView(viewModel: viewModel)
                BrowserToolbar(viewModel: viewModel)
            }
            .opacity(viewModel.isPlaying ? 0 : 1)

            if let player = viewModel.player {
                PlayerOverlay(player: player) {
                    viewModel.dismissPlayer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Player Overlay

private struct PlayerOverlay: View {
    let player: AVPlayer
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            VideoPlayer(player: player)
                .ignoresSafeArea()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(.top, 60)
            .padding(.leading, 16)
        }
    }
}

// MARK: - Browser Toolbar

private struct BrowserToolbar: View {
    let viewModel: DouyinPlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 24) {
                Button { viewModel.goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                }
                .disabled(!viewModel.canGoBack)

                Button { viewModel.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .medium))
                }
                .disabled(!viewModel.canGoForward)

                Button {
                    if viewModel.isLoading {
                        viewModel.stopLoading()
                    } else {
                        viewModel.reload()
                    }
                } label: {
                    Image(systemName: viewModel.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                }

                Text(viewModel.displayURL)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Button { viewModel.startPlayback() } label: {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(viewModel.hasVideoContent ? .blue : .gray)
                }
                .disabled(!viewModel.hasVideoContent)

                Button { viewModel.goHome() } label: {
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
