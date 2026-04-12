# Douyin iOS Wiki - 인덱스

> 마지막 업데이트: 2026-04-12 | 페이지 수: 14

## 개요

- [프로젝트 개요](overview.md) — 앱의 목적, 기술 스택, 핵심 가치
- [아키텍처](architecture.md) — 레이어 구조, 컴포넌트 관계, ZStack 전략

## 컴포넌트 (파일별 상세)

- [DouyinBrowserView](components/douyin-browser-view.md) — SwiftUI 메인 뷰, 스와이프 플레이어, 툴바
- [DouyinPlayerViewModel](components/douyin-player-viewmodel.md) — 상태 관리 허브, AVPlayer, URL 큐
- [WebViewCoordinator](components/web-view-coordinator.md) — JS→Swift 메시지 수신, KVO 관찰
- [DouyinJavaScript](components/douyin-javascript.md) — 4개 주입 스크립트 상세
- [DouyinWebView](components/douyin-webview.md) — UIViewRepresentable 래퍼

## 핵심 개념

- [5계층 영상 URL 추출](concepts/video-extraction.md) — 다계층 방어적 URL 추출 전략
- [URL 처리와 CDN 접근](concepts/url-handling.md) — URL 정제, Referer 헤더, CDN 도메인
- [프리페치 시스템](concepts/prefetch.md) — 상태 머신, 트리거 조건, API 호출
- [스와이프 플레이어](concepts/swipe-player.md) — 제스처 인식, UI 오버레이, 화면 전환
- [JS ↔ Swift 브릿지](concepts/js-swift-bridge.md) — 메시지 프로토콜, 주입 시점, 에러 처리
- [데이터 흐름](concepts/data-flow.md) — 전체 흐름도, URL 생명주기, 상태 전이
- [알려진 제한사항](concepts/known-limitations.md) — 외부/내부 제한 10가지

## 가이드

- [디버깅 가이드](guides/debugging.md) — 로그 확인, 흔한 문제 해결, Web Inspector
- [확장 가이드](guides/extending.md) — 새 추출 계층, CDN 도메인, UI 확장 패턴

## 메타

- [위키 스키마](SCHEMA.md) — 위키 운영 규칙, 디렉토리 구조, 페이지 형식
- [변경 로그](log.md) — 위키 변경 이력
