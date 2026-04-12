---
title: 확장 가이드
category: guide
related: [../architecture.md, ../concepts/video-extraction.md, ../concepts/prefetch.md]
sources: []
---

# 확장 가이드

코드베이스를 확장할 때 참고할 패턴과 주의사항.

## 새 영상 추출 계층 추가

### 체크리스트
1. `DouyinJavaScript.swift`에 새 스크립트 또는 기존 스크립트에 로직 추가
2. 새 메시지 타입이 필요하면 `WebViewCoordinator`에 케이스 추가
3. `DouyinPlayerViewModel`에 처리 메서드 추가
4. 중복 설치 방지 플래그 추가 (예: `__douyinNewFeatureInstalled`)
5. CLAUDE.md의 추출 계층 문서 업데이트

### 패턴
```javascript
// 1. 전역 플래그로 중복 방지
if (window.__douyinNewFeature) return;
window.__douyinNewFeature = true;

// 2. 로직 구현
// ...

// 3. 결과를 Swift로 전송
window.webkit.messageHandlers.douyin.postMessage({
    type: 'newType',
    value: extractedData
});
```

## 새 CDN 도메인 추가

`DouyinJavaScript.swift`의 `isRealVideoURL()` 함수에 패턴 추가:

```javascript
if (url.includes('new-cdn-domain.com')) return true;
```

## UI 확장

### 현재 뷰 계층
```
DouyinBrowserView (ZStack)
├── DouyinWebView
├── SwipePlayerView
└── BrowserToolbar
```

새 UI 요소는 이 ZStack 내에 추가하되, `opacity` 바인딩과 레이어 순서에 주의.

### SwipePlayerView 오버레이 추가
SwipePlayerView 내 ZStack에 새 오버레이를 추가할 수 있음. 기존 패턴:
- 좌상단: 닫기 버튼
- 우상단: 인덱스 카운터
- 하단: 제목

## 주의사항

### Swift 문자열 내 JavaScript
`"""` 멀티라인 문자열에서 정규식 백슬래시가 이중 이스케이프됨:
```swift
// ❌ 정규식 리터럴 사용 불가
let script = """
/pattern\\.test/
"""
// ✅ new RegExp() 사용
let script = """
new RegExp('pattern\\\\.test')
"""
```

### WKWebView 상태 보존
- WKWebView를 조건부 렌더링(`if`)으로 제거하면 상태 리셋
- 항상 `opacity`로 숨기기
- 쿠키, JS 전역 변수, 스크롤 위치 모두 보존됨

### 메모리 관리
- ViewModel에서 WKWebView 참조 시 직접 보유 (strong)
- Coordinator에서 ViewModel 참조 시 주의 (현재 unowned)
- AVPlayer 해제: `dismissPlayer()`에서 nil 할당으로 해제

### ATS (App Transport Security)
`Info.plist`에서 `NSAllowsArbitraryLoads = true`로 HTTP 허용 중. CDN 중 HTTP를 사용하는 경우가 있어 필요하지만, 프로덕션에서는 도메인별 예외로 전환 권장.
