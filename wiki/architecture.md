---
title: 아키텍처
category: overview
related: [overview.md, components/douyin-browser-view.md, components/douyin-player-viewmodel.md, concepts/data-flow.md]
sources: [모든 Swift 파일]
---

# 아키텍처

## 파일 구조

```
App.swift                  ← @main 엔트리 포인트 (10줄)
DouyinBrowserView.swift    ← SwiftUI 뷰 레이어 (236줄)
DouyinWebView.swift        ← WKWebView UIViewRepresentable 래퍼 (19줄)
WebViewCoordinator.swift   ← WebKit ↔ SwiftUI 브릿지 (100줄)
DouyinPlayerViewModel.swift ← 상태 관리 + 비즈니스 로직 (301줄)
DouyinJavaScript.swift     ← 주입 JavaScript 코드 (367줄)
Info.plist                 ← ATS 예외 설정
```

**총 ~1,033줄** (Swift 코드 + JS 문자열)

## 레이어 구조

```
┌─────────────────────────────────────────┐
│            SwiftUI View Layer           │
│  DouyinBrowserView / SwipePlayerView    │
│  BrowserToolbar / PlayerLayerView       │
├─────────────────────────────────────────┤
│          State Management Layer         │
│        DouyinPlayerViewModel            │
│   (@Observable, AVPlayer, URL 큐)       │
├─────────────────────────────────────────┤
│           Bridge Layer                  │
│  DouyinWebView (UIViewRepresentable)    │
│  WebViewCoordinator (Delegate+Handler)  │
├─────────────────────────────────────────┤
│          WebKit + JS Layer              │
│  WKWebView + 4개 주입 스크립트          │
│  networkIntercept / videoIntercept      │
│  scrollToLoadMore / getCurrentVideo     │
└─────────────────────────────────────────┘
```

## 컴포넌트 관계

```
App (@main)
  └── DouyinBrowserView (ZStack)
        ├── DouyinWebView
        │     ├── WKWebView (viewModel.createWebView())
        │     └── WebViewCoordinator
        │           ├── WKScriptMessageHandler → ViewModel
        │           └── WKNavigationDelegate → ViewModel
        ├── BrowserToolbar → ViewModel (navigation)
        └── SwipePlayerView (isPlaying == true)
              ├── PlayerLayerView (AVPlayerLayer)
              └── Gesture/UI overlays
```

## 소유권 모델

- **DouyinPlayerViewModel**이 중심 허브: WKWebView 인스턴스, AVPlayer, URL 큐, 모든 상태를 소유
- **DouyinBrowserView**는 ViewModel을 `@State`로 보유하고 하위 뷰에 전달
- **WebViewCoordinator**는 ViewModel의 약한 참조를 통해 메시지 전달 (retain cycle 방지)
- **JavaScript 코드**는 `DouyinJavaScript` enum의 static 문자열로 관리

## ZStack 레이어링 전략

WKWebView는 자체 컴포지팅 레이어를 사용하여 SwiftUI 뷰 위에 그려지는 문제가 있음. 해결책:

```
ZStack {
    DouyinWebView()          // 항상 존재
        .opacity(isPlaying ? 0 : 1)  // 재생 시 투명
    
    if isPlaying {
        SwipePlayerView()    // 플레이어 오버레이
    }
    
    BrowserToolbar()         // 항상 최상단
        .opacity(isPlaying ? 0 : 1)
}
```

`opacity(0)`을 사용하는 이유: `isHidden`이나 조건부 렌더링은 WKWebView의 상태를 리셋할 수 있음. `opacity(0)`은 뷰를 유지하면서 시각적으로만 숨김.
