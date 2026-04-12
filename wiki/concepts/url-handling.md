---
title: URL 처리와 CDN 접근
category: concept
related: [video-extraction.md, ../components/douyin-player-viewmodel.md]
sources: [DouyinPlayerViewModel.swift, DouyinJavaScript.swift]
---

# URL 처리와 CDN 접근

## URL 정제 (cleanURL)

추출된 URL은 여러 이유로 "더럽습니다". `cleanURL()` 메서드가 정제:

### 1. JSON 이스케이프 제거
```
https:\/\/v3-web.douyinvod.com\/...  →  https://v3-web.douyinvod.com/...
```
API 응답 JSON에서 추출 시 `/`가 `\/`로 이스케이프됨.

### 2. 워터마크 URL 변환
```
.../playwm/...  →  .../play/...
```
`/playwm/` 경로는 워터마크가 삽입된 버전. `/play/`로 변환하면 원본 화질 영상.

## CDN URL 판별 (isRealVideoURL)

JavaScript에서 `blob:` URL과 실제 CDN URL을 구분:

### 제외 조건
- `blob:` 프로토콜 (MSE 스트림, 브라우저 메모리에서만 유효)

### 포함 조건 (하나라도 매칭)
| 패턴 | 설명 |
|------|------|
| `douyinvod` | Douyin 전용 VOD CDN |
| `tos-cn-ve` | ByteDance TOS 스토리지 |
| `bytecdn` | ByteDance CDN |
| `zjcdn.com` | 장쟝 CDN |
| `/video/tos/` | TOS 영상 경로 |
| `video_id=` | 영상 ID 파라미터 |

## Referer 헤더

**CDN 서버가 403을 반환하는 핵심 원인**: Referer 헤더 누락.

AVPlayer에서 CDN URL을 직접 재생하려면 반드시 Referer 헤더 설정:

```swift
let headers = ["Referer": "https://www.douyin.com/"]
let asset = AVURLAsset(url: videoURL, options: [
    "AVURLAssetHTTPHeaderFieldsKey": headers
])
```

`AVURLAssetHTTPHeaderFieldsKey`는 비공개 API이지만 실제로 동작하며, CDN에서 요구하는 Referer 검증을 통과합니다.

## webid 토큰 처리

일부 CDN URL에 `tk=webid` 파라미터가 포함:
1. WKWebView 쿠키 스토어에서 `webid` 쿠키 값 조회
2. URL의 `tk=webid`를 실제 쿠키 값으로 치환

## CDN URL 수명

CDN URL에는 만료 타임스탬프가 포함됩니다. 일반적으로 수 시간 유효하지만, 장시간 방치 후에는 재생이 실패할 수 있습니다. 이 경우 새로운 URL을 추출해야 합니다.

## User-Agent 전략

모바일 웹 버전 접근을 위해 iOS Safari UA 사용:

```
Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)
AppleWebKit/605.1.15 (KHTML, like Gecko)
Version/17.0 Mobile/15E148 Safari/604.1
```

같은 `www.douyin.com` 도메인이지만, 모바일 UA로 접근하면 모바일 최적화 웹 페이지가 제공됩니다. 모바일 웹 버전이 영상 URL 추출에 더 유리합니다.
