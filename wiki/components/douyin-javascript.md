---
title: DouyinJavaScript (JS 주입 코드)
category: component
related: [web-view-coordinator.md, ../concepts/video-extraction.md, ../concepts/js-swift-bridge.md]
sources: [DouyinJavaScript.swift]
---

# DouyinJavaScript

**파일**: `DouyinJavaScript.swift` (367줄)

`enum DouyinJavaScript`에 4개의 static 문자열 프로퍼티로 JavaScript 코드를 관리합니다.

## 1. networkInterceptScript (문서 시작 시 주입)

**목적**: XHR/fetch API를 가로채서 영상 URL 추출

**주입 시점**: `WKUserScript(.atDocumentStart)` — DOM 생성 전에 네트워크 후킹

**동작**:
1. `window.fetch`를 프록시로 교체
   - 원본 fetch 호출 후 응답을 clone하여 JSON 파싱
   - `play_addr` 포함 시 영상 정보 추출
2. `XMLHttpRequest.prototype.send`를 래핑
   - `load` 이벤트에서 `responseText` 파싱
   - `play_addr` 포함 시 영상 정보 추출

**헬퍼 함수**:

### isRealVideoURL(url)
실제 CDN URL 판별. 조건:
- `blob:` URL 제외
- 도메인 패턴 매칭: `douyinvod`, `tos-cn-ve`, `bytecdn`, `zjcdn.com`, `/video/tos/`, `video_id=`

### findAllVideoInfo(obj, depth=8)
JSON 객체에서 재귀적으로 `play_addr.url_list[0]` 탐색.
- 최대 깊이 8로 제한 (성능)
- 각 결과에 `desc` (영상 설명)도 포함
- 결과: `[{url, desc}, ...]` 배열

**중복 방지**: `__douyinNetworkHooked` 전역 플래그로 1회만 설치

## 2. videoInterceptScript (문서 로드 후 주입)

**목적**: DOM 감시로 영상 요소 변화 실시간 감지

**주입 시점**: `WKUserScript(.atDocumentEnd)` — DOM 준비 완료 후

**동작**:

### IntersectionObserver
- 모든 `<video>` 요소를 관찰
- 뷰포트 진입 비율 50% 이상 시 "보이는 영상"으로 판정
- `visibleVideo` 메시지 전송 (url + desc)

### MutationObserver
- `childList` + `subtree`: 새 video 요소 추가 감지
- `attributeFilter: ['src']`: src 속성 변경 감지
- 새 요소 발견 시 IntersectionObserver에 등록

### 이벤트 후킹
- `play`, `loadeddata` 이벤트에서 src 추출
- 이벤트 발생 시 `visibleVideo` 메시지 전송

### URL 변경 감지
- `setInterval` (300ms)로 `location.href` 변화 폴링
- 변경 시 `urlChanged` 메시지 전송

### findVideoDesc(video)
video 요소에서 영상 제목 추출:
- 부모 노드를 최대 8레벨 탐색
- 텍스트 노드 중 적절한 길이(5~200자)의 텍스트 반환

**중복 방지**: `__douyinDOMInstalled` 전역 플래그

## 3. scrollToLoadMoreScript (온디맨드 실행)

**목적**: 추가 영상 로드 (프리페치)

**실행 시점**: `viewModel.triggerPrefetch()`에서 `evaluateJavaScript()`로 직접 호출

**동작**:
1. Douyin 피드 API 직접 호출: `https://www.douyin.com/aweme/v1/web/tab/feed/`
2. 파라미터: `device_platform=webapp`, `aid=6383`, `count=10` 등
3. `__douyinFeedState`에 페이지네이션 커서 유지
4. 응답에서 `findAllVideoInfo()`로 영상 추출
5. `videoInfoList` 메시지로 결과 전송
6. `prefetchStatus` 메시지로 완료 신호: `"fetched_N"` 또는 에러

## 4. getCurrentVideoScript (온디맨드 실행)

**목적**: 현재 보이는 영상의 URL 반환

**실행 시점**: `viewModel.startPlayback()`에서 호출

**우선순위**:
1. 캐시된 `__douyinCurrentVisibleVideoSrc` (유효한 경우)
2. 재생 중인(paused=false) video 요소의 실제 URL
3. 뷰포트 내 video 요소 (rect 체크)
4. 페이지 내 첫 번째 video 요소의 실제 URL
5. null (없음)

## 공통 유틸리티

### post(type, value)
```javascript
window.webkit.messageHandlers.douyin.postMessage({type, value})
```
Swift의 `WKScriptMessageHandler`로 메시지 전송. 모든 JS → Swift 통신의 단일 진입점.

### 에러 처리
모든 핵심 로직이 try-catch로 감싸져 있음. JS 에러가 웹페이지 동작을 방해하지 않도록 설계.
