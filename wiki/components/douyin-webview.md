---
title: DouyinWebView (UIViewRepresentable)
category: component
related: [web-view-coordinator.md, douyin-player-viewmodel.md]
sources: [DouyinWebView.swift]
---

# DouyinWebView

**파일**: `DouyinWebView.swift` (19줄)

가장 단순한 컴포넌트. WKWebView를 SwiftUI에서 사용하기 위한 `UIViewRepresentable` 래퍼.

## 역할

1. `makeUIView()`: ViewModel의 `createWebView()`를 호출하여 설정 완료된 WKWebView 반환
2. `makeCoordinator()`: `WebViewCoordinator` 생성 (KVO 관찰 시작)
3. `updateUIView()`: 비어 있음 — 상태 업데이트는 ViewModel이 직접 처리

## 설계 의도

WKWebView의 생성과 설정은 ViewModel에 위임. DouyinWebView 자체는 SwiftUI 라이프사이클과의 인터페이스만 담당합니다. 이렇게 분리하면:

- ViewModel이 WKWebView 참조를 직접 보유 가능
- JavaScript 평가 등 명령적 조작이 가능
- 뷰 재생성 시에도 WKWebView 인스턴스 유지
