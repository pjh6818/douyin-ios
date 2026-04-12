---
title: 5계층 영상 URL 추출
category: concept
related: [../components/douyin-javascript.md, ../components/web-view-coordinator.md, url-handling.md, js-swift-bridge.md]
sources: [DouyinJavaScript.swift, WebViewCoordinator.swift]
---

# 5계층 영상 URL 추출

Douyin은 영상을 다양한 방식으로 제공하며, 페이지 타입(추천 피드, 개별 영상, 모달 등)에 따라 URL 노출 방식이 다릅니다. 이 앱은 5개 계층으로 방어적 추출을 수행합니다.

## 계층 구조

```
Layer 1: <video> src 직접 추출     ← 가장 직접적
Layer 2: SSR 데이터 파싱            ← 초기 로드
Layer 3: XHR/fetch 인터셉트        ← SPA 피드 (주력)
Layer 4: MutationObserver          ← DOM 변화 실시간
Layer 5: MIME 감지                 ← 최후 방어선
```

## Layer 1: `<video>` src 직접 추출

**적용 대상**: 모달 영상, src가 직접 설정된 경우

`videoInterceptScript`의 IntersectionObserver와 이벤트 후킹이 담당. video 요소의 `currentSrc` 또는 `src`에서 실제 CDN URL이 직접 노출되면 즉시 캡처.

**한계**: 대부분의 Douyin 영상은 MSE로 `blob:` URL을 사용하므로 이 방법으로 잡히지 않음.

## Layer 2: SSR 데이터 파싱

**적용 대상**: 첫 페이지 로드 시 서버 렌더링 데이터

`window._ROUTER_DATA` 또는 `#RENDER_DATA` 스크립트 태그에 포함된 JSON에서 `play_addr.url_list[0]`을 재귀 탐색. `findAllVideoInfo()` 함수가 깊이 8까지 탐색.

**한계**: SPA 전환 후에는 SSR 데이터가 갱신되지 않음.

## Layer 3: XHR/fetch 인터셉트 (주력)

**적용 대상**: 추천 피드, 스크롤 로드, API 기반 콘텐츠

`networkInterceptScript`가 `fetch`와 `XMLHttpRequest`를 후킹:

```
원본 fetch/XHR → 프록시 호출 → 원본 실행 → 응답 clone →
JSON 파싱 → play_addr 탐색 → videoInfoList 메시지 전송
```

가장 많은 영상을 캡처하는 주력 메커니즘. Douyin의 추천 피드는 무한 스크롤 API로 영상을 로드하므로, 이 API 응답을 가로채면 CDN URL을 대량으로 획득할 수 있습니다.

## Layer 4: MutationObserver

**적용 대상**: DOM 동적 변경 (SPA 전환, 사용자 상호작용)

`videoInterceptScript`의 MutationObserver가 담당:
- 새 `<video>` 요소 추가 감지 → IntersectionObserver에 등록
- `src` 속성 변경 감지 → 즉시 캡처

Layer 1을 보완하여, 페이지 전환 후 새로 삽입되는 video 요소도 놓치지 않습니다.

## Layer 5: MIME 감지

**적용 대상**: WKWebView가 직접 영상 리소스로 네비게이션하는 경우

`WebViewCoordinator`의 `decidePolicyFor navigationResponse`에서:
- HTTP 응답의 `mimeType`이 `video/`로 시작하거나 `mpegURL`을 포함하면 URL 캡처

최후의 방어선. 다른 모든 계층이 실패해도 브라우저가 직접 영상 파일을 요청하면 잡힙니다.

## 왜 5계층인가

Douyin은 빈번하게 프론트엔드 구조를 변경합니다. 단일 추출 방법에 의존하면 업데이트 시 앱이 완전히 작동을 멈춥니다. 다계층 방어는:

1. **중복성**: 하나의 계층이 실패해도 다른 계층이 보완
2. **커버리지**: 페이지 타입마다 다른 영상 제공 방식에 대응
3. **시점 다양성**: 페이지 로드 전(L2) → 로드 중(L3) → 로드 후(L1,L4) → 네비게이션(L5)
