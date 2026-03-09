# CLAUDE.md

## 프로젝트 개요

Douyin(抖音) 웹사이트를 WKWebView로 탐색하며, JavaScript 인젝션으로 영상 CDN URL을 추출하여 AVPlayer로 네이티브 재생하는 iOS SwiftUI 앱.

## 빌드

```bash
xcodebuild build -project DouyinPlayerApp.xcodeproj -scheme DouyinPlayerApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## 아키텍처 (단일 파일: DouyinPlayer.swift)

- **DouyinBrowserView** — SwiftUI 메인 뷰. ZStack으로 웹뷰/플레이어 전환 (opacity 기반)
- **DouyinWebView** — UIViewRepresentable WKWebView 래퍼
- **DouyinBrowser** — ObservableObject 코디네이터. WKWebView 설정, JS 인젝션, URL 추출, AVPlayer 관리
  - `WKScriptMessageHandler` — JS → Swift 메시지 수신 (douyin 채널)
  - `WKNavigationDelegate` — 페이지 로드 시 JS 재인젝션, MIME 감지

## 영상 URL 추출 (5계층)

1. **`<video>` src 직접 추출** — CDN URL이 직접 설정된 경우 (모달 영상)
2. **SSR 데이터 파싱** — `window._ROUTER_DATA` / `#RENDER_DATA` → `play_addr.url_list[0]` 재귀 탐색
3. **XHR/fetch 인터셉트** — API 응답(`/aweme/v2/web/module/feed/` 등)에서 `play_addr` 추출. 추천 피드의 blob: URL 대응
4. **MutationObserver** — video 요소 추가/src 변경 실시간 감지
5. **MIME 감지** — WKNavigationDelegate에서 video/* 응답 URL 캡처

## 핵심 기술 포인트

- **Referer 헤더 필수**: CDN 403 방지 → `AVURLAssetHTTPHeaderFieldsKey`로 `Referer: https://www.douyin.com/` 설정
- **데스크톱 UA 필수**: 모바일 리다이렉트 방지 → Safari macOS UA 사용
- **WKWebView 레이어 문제**: 자체 컴포지팅 레이어로 SwiftUI 위에 그려짐 → 재생 시 `opacity(0)` 숨김
- **미디어 자동재생 차단**: `mediaTypesRequiringUserActionForPlayback = .all`
- **Swift 문자열 내 JS 정규식**: `"""` 멀티라인 문자열에서 `\\`가 이중 이스케이프됨 → 정규식 리터럴 대신 `new RegExp()` 사용
- **URL 정제**: `\\/` → `/` (JSON 이스케이프), `/playwm/` → `/play/` (워터마크 제거)

## JS → Swift 메시지 타입

| 타입 | 설명 |
|---|---|
| `videoSrc` | `<video>` src에서 직접 추출 |
| `ssrData` | SSR 데이터에서 추출 |
| `apiIntercept` | XHR/fetch API 응답 JSON에서 추출 |
| `apiRegex` | API 응답에서 정규식 폴백 추출 |

## URL 필터링

실제 영상 URL 판별 기준 (isRealVideoURL):
- `blob:` URL 제외
- 도메인 패턴: `douyinvod`, `tos-cn-ve`, `bytecdn`, `zjcdn.com`, `/video/tos/`

## 파일 구조

```
App.swift              — @main 엔트리 포인트
DouyinPlayer.swift     — 전체 구현 (뷰 + 브라우저 + JS)
Info.plist             — ATS 예외 (NSAllowsArbitraryLoads)
```

## 알려진 제한

- Douyin이 API 구조를 변경하면 XHR 인터셉트가 동작하지 않을 수 있음
- CDN URL에 만료 시간이 포함되어 있어 장시간 후 재생 실패 가능
- 로그인 필요한 컨텐츠는 접근 불가
