# Douyin iOS Player

WKWebView로 Douyin(抖音) 웹사이트를 탐색하면서, 영상의 실제 CDN URL을 추출하여 네이티브 AVPlayer로 재생하는 iOS SwiftUI 앱.

## 개요

Douyin 웹 플레이어는 MediaSource Extensions(MSE)를 통해 `blob:` URL로 영상을 재생하기 때문에, 단순히 `<video>` 태그의 `src` 속성만으로는 실제 영상 파일 URL을 얻을 수 없다. 이 앱은 JavaScript 인젝션을 통해 여러 계층에서 영상 URL을 추출하고, `AVPlayer`로 네이티브 재생을 구현한다.

## 요구사항

- iOS 17.0+
- Xcode 16+
- Swift 5.0+

## 프로젝트 구조

```
├── App.swift                          # @main 엔트리 포인트
├── DouyinPlayer.swift                 # 전체 구현 (단일 파일)
│   ├── DouyinBrowserView              # SwiftUI 메인 뷰 (웹뷰 + 플레이어 + 툴바)
│   ├── DouyinWebView                  # UIViewRepresentable WKWebView 래퍼
│   └── DouyinBrowser                  # ObservableObject 코디네이터
│       ├── WKScriptMessageHandler     # JS → Swift 메시지 수신
│       └── WKNavigationDelegate       # 페이지 로드/MIME 감지
├── Info.plist                         # ATS 예외 설정 (NSAllowsArbitraryLoads)
└── DouyinPlayerApp.xcodeproj          # Xcode 프로젝트
```

### 코드 구조 상세

| 컴포넌트 | 역할 |
|---|---|
| `DouyinBrowserView` | ZStack으로 웹뷰와 VideoPlayer를 겹쳐 배치. 재생 중에는 웹뷰를 `opacity(0)`으로 숨김 |
| `DouyinWebView` | `UIViewRepresentable`로 WKWebView를 SwiftUI에 임베딩 |
| `DouyinBrowser` | 핵심 로직. WKWebView 설정, JS 인젝션, URL 추출, AVPlayer 제어를 담당하는 `ObservableObject` |
| `videoInterceptScript` | 페이지에 주입되는 JavaScript. 5가지 방법으로 영상 URL을 추출 |

## 비디오 URL 추출 원리

Douyin 페이지의 영상 URL은 다양한 형태로 존재한다. 이 앱은 5가지 계층의 추출 전략을 사용한다.

### 1단계: `<video>` 요소 직접 추출

```
<video src="https://v5-hl-qn-ov.zjcdn.com/..."> → 직접 추출
```

일부 페이지(모달 영상 등)에서는 `<video>` 태그의 `src`에 실제 CDN URL이 직접 설정된다. `document.querySelectorAll('video')`로 모든 video 요소를 순회하며 `src` 또는 `<source>` 자식 요소에서 URL을 추출한다.

**URL 필터링 기준:**
- `blob:` URL 제외 (MSE 스트림이므로 직접 재생 불가)
- 도메인 패턴 매칭: `douyinvod`, `tos-cn-ve`, `bytecdn`, `zjcdn.com`, `/video/tos/`

### 2단계: SSR(Server-Side Rendering) 데이터 파싱

Douyin은 초기 페이지 로드 시 서버에서 렌더링한 데이터를 두 가지 형태로 포함시킨다:

- **`window._ROUTER_DATA`**: 전역 JavaScript 객체
- **`#RENDER_DATA`**: `<script id="RENDER_DATA">` 태그 내 URL-encoded JSON

두 데이터 모두 `play_addr.url_list[0]` 구조로 영상 URL을 포함한다. `findPlayAddr()` 함수가 최대 깊이 8까지 재귀 탐색하여 URL을 찾는다.

```
window._ROUTER_DATA → 재귀 탐색 → play_addr.url_list[0] → CDN URL
```

### 3단계: XHR/Fetch API 인터셉트

추천(정선) 피드 영상은 SPA 방식으로 로드되며, `<video>` 태그에는 `blob:` URL만 설정된다. 실제 영상 URL은 Douyin API 응답에 포함되어 있다.

**인터셉트 방식:**

```javascript
// fetch 인터셉트
var origFetch = window.fetch;
window.fetch = function() {
    return origFetch.apply(this, arguments).then(function(response) {
        var clone = response.clone();
        clone.text().then(function(text) {
            if (text.includes('play_addr')) {
                // JSON 파싱 → findPlayAddr() → URL 추출
            }
        });
        return response;  // 원본 응답은 그대로 반환
    });
};

// XMLHttpRequest 인터셉트
var origXHRSend = XMLHttpRequest.prototype.send;
XMLHttpRequest.prototype.send = function() {
    this.addEventListener('load', function() {
        if (this.responseText.includes('play_addr')) {
            // JSON 파싱 → findPlayAddr() → URL 추출
        }
    });
    return origXHRSend.apply(this, arguments);
};
```

주요 API 엔드포인트:
- `/aweme/v2/web/module/feed/` — 정선/추천 피드 영상 목록
- `/aweme/v1/web/aweme/detail/` — 개별 영상 상세

### 4단계: DOM MutationObserver

SPA 특성상 `<video>` 요소가 동적으로 추가/변경된다. `MutationObserver`로 실시간 감시한다:

- **`childList`**: 새로운 `<video>` 노드 추가 감지
- **`attributes`** (`attributeFilter: ['src']`): 기존 video의 `src` 속성 변경 감지
- **이벤트 훅**: 각 video 요소에 `play`, `loadeddata` 이벤트 리스너를 등록하여 재생 시작 시점에 URL 재추출

### 5단계: Navigation Response MIME 감지

`WKNavigationDelegate`의 `decidePolicyFor navigationResponse`에서 응답의 MIME 타입이 `video/*` 또는 `mpegURL`인 경우 해당 URL을 캡처한다. WKWebView가 직접 영상 리소스를 요청하는 경우에 대한 폴백이다.

### URL 추출 흐름도

```
페이지 로드
 ├── [atDocumentEnd] JS 인젝션 → fetch/XHR 인터셉터 설치
 ├── [didFinish] JS 재인젝션 (SPA 네비게이션 대응)
 │
 ├── video 요소 직접 추출 ──→ CDN URL 발견? → storeVideoURL()
 ├── SSR 데이터 파싱 ────────→ play_addr 발견? → storeVideoURL()
 ├── XHR/fetch 응답 감시 ───→ play_addr 발견? → storeVideoURL()
 ├── MutationObserver ──────→ video 추가/변경? → extractFromVideos()
 └── MIME 타입 감지 ─────────→ video/* 응답? → storeVideoURL()
                                     │
                                     ▼
                          extractedVideoURL에 저장
                          (툴바 재생 버튼 활성화)
                                     │
                              사용자 재생 버튼 탭
                                     │
                                     ▼
                     AVURLAsset + Referer 헤더 → AVPlayer 재생
```

## AVPlayer 재생 시 핵심 처리

### Referer 헤더

Douyin CDN은 `Referer` 헤더를 검증한다. 헤더가 없으면 403 Forbidden이 반환된다.

```swift
let headers = ["Referer": "https://www.douyin.com/"]
let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
```

### User-Agent 설정

iOS Safari UA를 설정하여 모바일 웹 버전으로 접근한다. Douyin 모바일 웹도 주소는 `www.douyin.com`으로 동일하다.

```swift
wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 ..."
```

### WKWebView 레이어 문제

WKWebView는 자체 컴포지팅 레이어에서 렌더링되어, SwiftUI의 `zIndex`나 `overlay`로는 위에 뷰를 올릴 수 없다. AVPlayer 재생 시 웹뷰를 `opacity(0)`으로 완전히 숨기는 방식으로 해결한다.

```swift
VStack { DouyinWebView(browser: browser) }
    .opacity(isPlaying ? 0 : 1)  // 재생 중에는 웹뷰 숨김
```

### 웹뷰 미디어 자동재생 차단

웹뷰 내 영상이 자동 재생되면 AVPlayer와 동시에 소리가 나는 문제가 발생한다. 모든 미디어 타입에 대해 사용자 액션을 요구하도록 설정한다.

```swift
config.mediaTypesRequiringUserActionForPlayback = .all
```

## URL 정제 처리

추출된 URL에 대해 두 가지 정제를 수행한다:

| 변환 | 이유 |
|---|---|
| `\/` → `/` | JSON 응답에서 이스케이프된 슬래시 복원 |
| `/playwm/` → `/play/` | 워터마크 없는 버전으로 전환 |

## JS → Swift 통신

`WKScriptMessageHandler`를 통해 JavaScript에서 Swift로 메시지를 전달한다.

```javascript
// JavaScript 측
window.webkit.messageHandlers.douyin.postMessage({
    type: 'apiIntercept',    // 추출 방법 식별자
    value: 'https://...'     // CDN URL
});
```

```swift
// Swift 측
func userContentController(_ controller: WKUserContentController,
                           didReceive message: WKScriptMessage) {
    guard let dict = message.body as? [String: String],
          let type = dict["type"],
          let value = dict["value"] else { return }

    switch type {
    case "videoSrc", "ssrData", "apiIntercept", "apiRegex":
        storeVideoURL(value)
    default: break
    }
}
```

### 메시지 타입

| 타입 | 발생 조건 |
|---|---|
| `videoSrc` | `<video>` 요소의 `src`에서 직접 추출 |
| `ssrData` | `_ROUTER_DATA` 또는 `RENDER_DATA`에서 추출 |
| `apiIntercept` | XHR/fetch 응답 JSON의 `play_addr`에서 추출 |
| `apiRegex` | XHR/fetch 응답에서 정규식으로 추출 (JSON 파싱 실패 시 폴백) |

## 개발 과정에서 해결한 문제들

| 문제 | 원인 | 해결 |
|---|---|---|
| User-Agent | iOS 앱에서 모바일 웹 버전 사용 | iOS Safari UA 설정 |
| CDN 403 Forbidden | Douyin CDN의 Referer 검증 | `AVURLAssetHTTPHeaderFieldsKey`로 Referer 헤더 추가 |
| 웹뷰가 플레이어 위에 표시 | WKWebView의 자체 컴포지팅 레이어 | `opacity(0)`으로 웹뷰 숨김 |
| 배경 프로모 영상 캡처 | `uuu_265.mp4` 등 배경 영상이 video 요소로 존재 | CDN 도메인 패턴으로 필터링 |
| 추천 피드 영상 미감지 | MSE 기반 `blob:` URL 사용 | XHR/fetch 인터셉트로 API 응답에서 추출 |
| 스크롤 후 이전 영상 재생 | video 요소 src 변경을 감지하지 못함 | MutationObserver + play/loadeddata 이벤트 훅 |
| Swift 문자열 내 JS 정규식 오류 | `"""` 문자열에서 `\` 이스케이프가 이중 적용 | `new RegExp()` 생성자 사용으로 우회 |

## 라이선스

MIT
