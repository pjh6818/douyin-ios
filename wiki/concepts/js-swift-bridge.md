---
title: JavaScript ↔ Swift 브릿지
category: concept
related: [../components/douyin-javascript.md, ../components/web-view-coordinator.md, video-extraction.md]
sources: [DouyinJavaScript.swift, WebViewCoordinator.swift, DouyinPlayerViewModel.swift]
---

# JavaScript ↔ Swift 브릿지

WKWebView의 JS-Swift 통신 메커니즘.

## JS → Swift (메시지)

### 전송 방식
```javascript
window.webkit.messageHandlers.douyin.postMessage({type, value})
```

`"douyin"` 채널은 WKWebView 설정 시 등록:
```swift
contentController.add(coordinator, name: "douyin")
```

### 메시지 타입

| type | value | 설명 | 처리 |
|------|-------|------|------|
| `visibleVideo` | `{url, desc}` 또는 URL 문자열 | 보이는 영상 변경 | `replaceWithVisibleVideo()` |
| `videoInfoList` | `[{url, desc}, ...]` JSON | 영상 목록 (API/프리페치) | `storeVideoInfoList()` |
| `prefetchStatus` | `"fetched_N"` 또는 에러 문자열 | 프리페치 결과 | `resolvePendingPrefetch()` / `handlePrefetchFailure()` |
| `urlChanged` | URL 문자열 | SPA 네비게이션 | `clearVideoURL()` |

### 수신 처리
`WebViewCoordinator.userContentController(_:didReceive:)`에서:
1. `message.body`를 `[String: Any]`로 캐스팅
2. `type` 키로 분기
3. `value`를 적절한 타입으로 파싱

## Swift → JS (스크립트 실행)

### 정적 주입 (페이지 로드 시)
```swift
WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
```

| 스크립트 | 시점 | 역할 |
|----------|------|------|
| `networkInterceptScript` | documentStart | fetch/XHR 후킹 (DOM 전) |
| `videoInterceptScript` | documentEnd | DOM 관찰 시작 |

### 동적 실행 (온디맨드)
```swift
webView.evaluateJavaScript(script) { result, error in ... }
```

| 스크립트 | 호출 시점 | 반환값 |
|----------|----------|--------|
| `getCurrentVideoScript` | 재생 버튼 탭 | URL 문자열 또는 null |
| `scrollToLoadMoreScript` | 프리페치 트리거 | 없음 (메시지로 결과 전달) |

### 페이지 전환 시 재주입
SPA 네비게이션 시 JS가 초기화될 수 있으므로, `didFinish` 델리게이트에서 두 스크립트를 재주입:
```swift
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    webView.evaluateJavaScript(DouyinJavaScript.networkInterceptScript)
    webView.evaluateJavaScript(DouyinJavaScript.videoInterceptScript)
}
```

중복 설치 방지: 각 스크립트는 `__douyinNetworkHooked` / `__douyinDOMInstalled` 전역 플래그로 1회만 설치.

## 에러 처리 전략

- **JS 측**: 모든 핵심 로직을 `try-catch`로 감싸서 웹페이지 동작을 방해하지 않음
- **Swift 측**: `evaluateJavaScript`의 completion handler에서 에러 로깅 (`os_log`)
- **통신 실패**: 메시지 파싱 실패 시 해당 메시지 무시 (로그 기록)
