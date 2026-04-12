---
title: DouyinPlayerViewModel (상태 관리)
category: component
related: [web-view-coordinator.md, douyin-browser-view.md, douyin-javascript.md, ../concepts/prefetch.md, ../concepts/url-handling.md]
sources: [DouyinPlayerViewModel.swift]
---

# DouyinPlayerViewModel

**파일**: `DouyinPlayerViewModel.swift` (301줄)

`@Observable` 클래스. 앱의 모든 상태와 비즈니스 로직을 관리하는 중심 허브.

## 상태 프로퍼티

### 뷰 바인딩 상태
| 프로퍼티 | 타입 | 설명 |
|----------|------|------|
| `player` | `AVPlayer?` | 현재 플레이어. nil이면 재생 중 아님 |
| `canGoBack` | `Bool` | 뒤로가기 가능 여부 |
| `canGoForward` | `Bool` | 앞으로가기 가능 여부 |
| `isLoading` | `Bool` | 페이지 로딩 중 여부 |
| `displayURL` | `String` | 현재 URL의 호스트명 |
| `hasVideoContent` | `Bool` | 재생 가능한 영상 존재 여부 |

### 영상 관리 상태
| 프로퍼티 | 타입 | 설명 |
|----------|------|------|
| `extractedVideoURL` | `String?` | 현재 재생 중인 URL |
| `videoURLs` | `[String]` | URL 대기열 (순서 보존) |
| `videoTitles` | `[String: String]` | URL → 제목 매핑 |
| `prefetchState` | `PrefetchState` | 프리페치 상태머신 |
| `pendingAutoPlayNext` | `Bool` | 프리페치 완료 후 자동 재생 플래그 |

### 내부 상태
| 프로퍼티 | 타입 | 설명 |
|----------|------|------|
| `webView` | `WKWebView?` | 웹뷰 참조 |
| `prefetchTimer` | `Timer?` | 프리페치 타임아웃 (8초) |

## 계산 프로퍼티

- `isPlaying`: `player != nil`
- `currentIndex`: 대기열에서 현재 URL의 1-based 인덱스
- `currentTitle`: 현재 영상 제목 (videoTitles에서 조회)
- `nextVideoURL`: 대기열의 다음 URL (없으면 nil)
- `previousVideoURL`: 대기열의 이전 URL (없으면 nil)

## 핵심 메서드

### WebView 생성

```
createWebView() → WKWebView
```
- `WKWebViewConfiguration` 설정: 인라인 재생 허용, 자동재생 차단 해제
- User Script 주입: `networkInterceptScript` (documentStart), `videoInterceptScript` (documentEnd)
- Message Handler 등록: "douyin" 채널
- User-Agent: iOS Safari UA (모바일 웹 접근용)
- 홈 URL: `https://www.douyin.com/jingxuan`

### 재생 제어

| 메서드 | 설명 |
|--------|------|
| `startPlayback()` | JS로 현재 영상 URL 획득 → `playURL()` |
| `playURL(_ url)` | AVURLAsset 생성 (Referer 헤더) → AVPlayer 재생 |
| `playNext()` | 다음 URL 재생. 없으면 프리페치 트리거 |
| `playPrevious()` | 이전 URL 재생 |
| `dismissPlayer()` | 플레이어 정리. 웹뷰 내 video 요소도 일시정지 |

### URL 관리

| 메서드 | 설명 |
|--------|------|
| `storeVideoURL(_ url)` | 대기열에 URL 추가 (중복 무시) |
| `replaceWithVisibleVideo(_ url)` | 단일 URL로 대기열 교체 |
| `storeVideoInfoList(_ list)` | 배치 URL 추가 (프리페치 결과) |
| `clearVideoURL()` | 모든 영상 상태 초기화 |
| `cleanURL(_ url)` | `\/` → `/`, `/playwm/` → `/play/` 치환 |

### 프리페치

| 메서드 | 설명 |
|--------|------|
| `triggerPrefetch()` | API 호출 스크립트 실행, 8초 타임아웃 |
| `handlePrefetchFailure()` | 실패 처리, pending 플래그 해제 |
| `resolvePendingPrefetch()` | 성공 시 자동 재생 처리 |
| `checkProactivePrefetch()` | 대기열 ≤2개 시 선제적 프리페치 |

## playURL() 상세 흐름

1. URL 정제 (`cleanURL`)
2. WKWebView 쿠키 스토어에서 쿠키 조회
3. `tk=webid` 파라미터 처리: webid 쿠키 값을 토큰에 주입
4. `AVURLAsset` 생성: `Referer: https://www.douyin.com/` 헤더 필수
5. `AVPlayerItem` 생성
6. 기존 플레이어 있으면 `replaceCurrentItem()`, 없으면 새 `AVPlayer` 생성
7. `player.play()` 호출
8. 선제적 프리페치 확인 (`checkProactivePrefetch`)
