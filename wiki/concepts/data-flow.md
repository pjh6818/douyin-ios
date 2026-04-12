---
title: 데이터 흐름
category: concept
related: [../architecture.md, video-extraction.md, js-swift-bridge.md, prefetch.md]
sources: [모든 파일]
---

# 데이터 흐름

## 전체 흐름도

```
사용자가 앱 열기
    │
    ▼
App.swift → DouyinBrowserView 생성
    │
    ▼
DouyinPlayerViewModel 초기화
    │ createWebView()
    ▼
WKWebView 생성
    ├── UA: iOS Safari
    ├── 인라인 재생 허용
    ├── networkInterceptScript (documentStart)
    └── videoInterceptScript (documentEnd)
    │
    ▼
https://www.douyin.com/jingxuan 로드
    │
    ▼
JavaScript 실행 시작
    ├── fetch/XHR 후킹 (Layer 3)
    ├── DOM Observer 설정 (Layer 1, 4)
    └── SSR 데이터 파싱 (Layer 2)
    │
    ▼
영상 URL 발견 시 메시지 전송
    │
    ▼
WebViewCoordinator 메시지 수신
    │
    ▼
DouyinPlayerViewModel 상태 업데이트
    ├── videoURLs 대기열에 추가
    ├── videoTitles 매핑
    └── hasVideoContent = true
    │
    ▼
사용자가 ▶ 탭
    │
    ▼
getCurrentVideoScript 실행
    │ URL 반환
    ▼
playURL()
    ├── cleanURL() 정제
    ├── 쿠키 조회 (webid 토큰)
    ├── AVURLAsset (Referer 헤더)
    ├── AVPlayerItem 생성
    ├── AVPlayer 재생
    └── checkProactivePrefetch()
    │
    ▼
SwipePlayerView 표시 (isPlaying = true)
    │
    ▼
스와이프 루프
    ├── 위로: playNext() → 다음 영상
    ├── 아래로: playPrevious() → 이전 영상
    └── 대기열 부족: triggerPrefetch() → API 호출 → 보충
    │
    ▼
X 버튼: dismissPlayer() → 웹 브라우저 복귀
```

## 영상 URL 생명주기

```
발견(JS)
  │ post("visibleVideo"/"videoInfoList")
  ▼
수신(Coordinator)
  │ parse & validate
  ▼
저장(ViewModel)
  │ storeVideoURL() / storeVideoInfoList()
  ▼
대기열(videoURLs)
  │ 사용자 선택 / 자동 재생
  ▼
정제(cleanURL)
  │ \/ → /, /playwm/ → /play/
  ▼
재생(playURL)
  │ AVURLAsset + Referer
  ▼
AVPlayer
```

## 상태 전이

### 브라우저 모드
```
[브라우징] ──▶ 탭 ──▶ [재생 모드]
    ▲                      │
    └── X 버튼 / dismiss ──┘
```

### 프리페치 연결
```
[재생 중] ── 스와이프 ──▶ [다음 영상]
    │                         │
    │ (남은 ≤ 2개)            │ (대기열 끝)
    ▼                         ▼
[선제적 프리페치]        [수동 프리페치]
    │                         │
    └── API 호출 ── 결과 ──▶ 대기열 보충
```
