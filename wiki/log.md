# 변경 로그

## [2026-04-12] 초기 구축 | 전체 코드베이스 지식화

전체 코드베이스를 분석하여 위키를 초기 구축했습니다.

**생성된 페이지 (14개)**:
- overview.md — 프로젝트 개요
- architecture.md — 아키텍처 + 레이어 구조
- components/douyin-browser-view.md — 메인 뷰 상세
- components/douyin-player-viewmodel.md — ViewModel 상세
- components/web-view-coordinator.md — Coordinator 상세
- components/douyin-javascript.md — JS 코드 상세
- components/douyin-webview.md — WebView 래퍼 상세
- concepts/video-extraction.md — 5계층 추출 전략
- concepts/url-handling.md — URL 처리/CDN 접근
- concepts/prefetch.md — 프리페치 상태 머신
- concepts/swipe-player.md — 스와이프 플레이어
- concepts/js-swift-bridge.md — JS↔Swift 통신
- concepts/data-flow.md — 전체 데이터 흐름
- concepts/known-limitations.md — 알려진 제한 10가지
- guides/debugging.md — 디버깅 가이드
- guides/extending.md — 확장 가이드

**분석 소스**: App.swift, DouyinBrowserView.swift, DouyinWebView.swift, WebViewCoordinator.swift, DouyinPlayerViewModel.swift, DouyinJavaScript.swift, Info.plist, CLAUDE.md, README.md
