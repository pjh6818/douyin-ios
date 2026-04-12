---
title: WebViewCoordinator (브릿지)
category: component
related: [douyin-player-viewmodel.md, douyin-webview.md, douyin-javascript.md]
sources: [WebViewCoordinator.swift]
---

# WebViewCoordinator

**파일**: `WebViewCoordinator.swift` (100줄)

WebKit과 SwiftUI 사이의 브릿지. `NSObject` 서브클래스로 두 가지 프로토콜을 구현합니다.

## WKScriptMessageHandler

JavaScript → Swift 메시지 수신. `"douyin"` 채널로 수신되는 메시지 타입:

### visibleVideo

현재 화면에 보이는 영상이 변경됨.

```json
{"url": "https://...", "desc": "영상 제목"}
```

- JSON 파싱 시도: url과 desc 추출
- 파싱 실패 시 문자열 전체를 URL로 사용
- `viewModel.replaceWithVisibleVideo()` 호출 → 대기열을 단일 항목으로 교체

### videoInfoList

API 인터셉트 또는 프리페치로 영상 목록 수신.

```json
[{"url": "https://...", "desc": "제목"}, ...]
```

- 프리페치 활성 상태(`scrolling`/`waiting`)일 때만 처리
- `viewModel.storeVideoInfoList()` 호출 → 배치 추가
- 프리페치 해결: `resolvePendingPrefetch()`

### prefetchStatus

프리페치 완료 시그널.

- `"fetched_N"` 접두사: 성공 (N개 영상)
- 그 외: 실패 → `handlePrefetchFailure()`

### urlChanged

SPA 네비게이션 감지. 페이지 URL 변경 시:
- `viewModel.clearVideoURL()` 호출 → 이전 영상 상태 정리

## WKNavigationDelegate

### didStartProvisionalNavigation
새 네비게이션 시작 → `clearVideoURL()`

### didFinish
페이지 로드 완료 → JavaScript 재주입
- `networkInterceptScript` + `videoInterceptScript`
- SPA 특성상 페이지 전환 시 JS가 초기화될 수 있으므로 매번 재주입

### decidePolicyFor (navigationResponse)
HTTP 응답의 MIME 타입 확인:
- `video/*` 또는 `mpegURL` → 직접 영상 URL 캡처
- `viewModel.storeVideoURL()` 호출
- 5계층 추출의 최후 방어선

## KVO 관찰

WebViewCoordinator가 WKWebView의 프로퍼티를 관찰하여 ViewModel에 반영:

| WKWebView 프로퍼티 | ViewModel 프로퍼티 |
|---------------------|---------------------|
| `canGoBack` | `canGoBack` |
| `canGoForward` | `canGoForward` |
| `isLoading` | `isLoading` |
| `url` | `displayURL` (호스트만) |
