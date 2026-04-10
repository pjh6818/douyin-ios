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

            if viewModel.player != nil {
                SwipePlayerView(viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Swipe Player View

private struct SwipePlayerView: View {
    let viewModel: DouyinPlayerViewModel
    @State private var dragOffset: CGFloat = 0
    @State private var isTransitioning = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player = viewModel.player {
                PlayerLayerView(player: player)
                    .ignoresSafeArea()
                    .offset(y: dragOffset)
            }

            // UI 오버레이
            HStack {
                Button { viewModel.dismissPlayer() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white, .black.opacity(0.6))
                }

                Spacer()

                if let idx = viewModel.currentIndex {
                    Text("\(idx) / \(viewModel.videoURLs.count)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.4), in: Capsule())
                }
            }
            .padding(.top, 60)
            .padding(.horizontal, 16)

            // 영상 제목
            if let title = viewModel.currentTitle, !title.isEmpty {
                VStack {
                    Spacer()
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.4))
                }
                .padding(.bottom, 16)
            }

            // 프리페치 로딩 인디케이터
            if viewModel.pendingAutoPlayNext &&
                (viewModel.prefetchState == .scrolling || viewModel.prefetchState == .waiting) {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("다음 영상 로딩 중...")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 80)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    guard !isTransitioning else { return }
                    if abs(value.translation.height) > abs(value.translation.width) {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    guard !isTransitioning else { return }
                    let threshold: CGFloat = 120
                    let velocity = value.predictedEndTranslation.height

                    if value.translation.height < -threshold || velocity < -500 {
                        swipe(direction: .next)
                    } else if value.translation.height > threshold || velocity > 500 {
                        swipe(direction: .previous)
                    } else {
                        withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
                    }
                }
        )
    }

    private enum Direction { case next, previous }

    private func swipe(direction: Direction) {
        let hasTarget = direction == .next ? viewModel.nextVideoURL != nil : viewModel.previousVideoURL != nil

        if !hasTarget {
            if direction == .next {
                // 마지막 영상 → prefetch 트리거
                viewModel.playNext()
                withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
            } else {
                withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
            }
            return
        }

        isTransitioning = true
        let screenHeight = UIScreen.main.bounds.height
        let targetOffset = direction == .next ? -screenHeight : screenHeight

        withAnimation(.easeIn(duration: 0.2)) {
            dragOffset = targetOffset
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if direction == .next {
                viewModel.playNext()
            } else {
                viewModel.playPrevious()
            }
            dragOffset = 0
            isTransitioning = false
        }
    }
}

// MARK: - AVPlayer UIKit Layer

private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
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
