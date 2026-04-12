---
title: DouyinBrowserView (메인 뷰)
category: component
related: [douyin-webview.md, douyin-player-viewmodel.md, ../concepts/swipe-player.md]
sources: [DouyinBrowserView.swift]
---

# DouyinBrowserView

**파일**: `DouyinBrowserView.swift` (236줄)

SwiftUI 메인 뷰. 웹 브라우저 + 영상 플레이어 + 툴바를 ZStack으로 합성합니다.

## 구조

### DouyinBrowserView (메인 컨테이너)

```swift
@State private var viewModel = DouyinPlayerViewModel()
```

ZStack 구성:
1. `DouyinWebView` — 웹 콘텐츠 (재생 시 `opacity(0)`)
2. `SwipePlayerView` — 영상 플레이어 오버레이 (`isPlaying` 시 표시)
3. `BrowserToolbar` — 하단 네비게이션 바 (재생 시 `opacity(0)`)

### SwipePlayerView (영상 플레이어)

전체화면 영상 재생 뷰. 핵심 기능:

- **PlayerLayerView**: `UIViewRepresentable`로 `AVPlayerLayer` 렌더링
  - `videoGravity = .resizeAspectFill` (화면 채움)
  - 검정 배경
- **스와이프 제스처**: `DragGesture`로 상/하 스와이프 감지
  - 임계값: 120pt 거리 또는 500pt/s 속도
  - 위로 스와이프 → 다음 영상
  - 아래로 스와이프 → 이전 영상
- **UI 오버레이**:
  - 닫기 버튼 (좌상단 X)
  - 영상 인덱스 카운터 (우상단, 예: "3/10")
  - 영상 제목 (하단, 2줄 제한)
  - 프리페치 로딩 인디케이터 (`.scrolling`/`.waiting` 상태 시)

### BrowserToolbar (하단 툴바)

`.safeAreaInset(edge: .bottom)` 위치. 버튼 구성:

| 버튼 | 동작 | 상태 |
|------|------|------|
| ← | `goBack()` | `canGoBack` 시 활성화 |
| → | `goForward()` | `canGoForward` 시 활성화 |
| ↻ / ✕ | `reload()` / `stopLoading()` | `isLoading`에 따라 토글 |
| URL 표시 | — | 호스트명만 표시 |
| ▶ | `startPlayback()` | 파란색(영상 있음) / 회색(없음) |
| 🏠 | `goHome()` | 항상 활성 |

### PlayerLayerView (AVPlayerLayer 래퍼)

```swift
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    
    class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
    }
}
```

`UIView.layerClass`를 오버라이드하여 뷰의 기본 레이어를 `AVPlayerLayer`로 설정. 이 방식이 별도 서브레이어 추가보다 성능과 레이아웃이 우수합니다.
