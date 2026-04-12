---
title: 스와이프 플레이어
category: concept
related: [../components/douyin-browser-view.md, prefetch.md]
sources: [DouyinBrowserView.swift]
---

# 스와이프 플레이어

TikTok/Douyin 스타일의 전체화면 영상 탐색 인터페이스.

## 제스처 인식

`DragGesture`를 사용한 상/하 스와이프 감지:

```swift
.gesture(
    DragGesture()
        .onChanged { value in
            dragOffset = value.translation.height
        }
        .onEnded { value in
            let threshold: CGFloat = 120
            let velocity = value.predictedEndTranslation.height - value.translation.height
            
            if dragOffset < -threshold || velocity < -500 {
                // 위로 스와이프 → 다음 영상
            } else if dragOffset > threshold || velocity > 500 {
                // 아래로 스와이프 → 이전 영상
            }
            dragOffset = 0
        }
)
```

### 임계값
- **거리**: 120pt (화면의 약 15%)
- **속도**: 500pt/s (빠른 플릭 감지)
- 둘 중 하나만 충족해도 동작

## 영상 탐색 흐름

```
위로 스와이프
  ├── nextVideoURL 존재 → playNext() → 즉시 전환
  └── nextVideoURL 없음 → triggerPrefetch() → 로딩 → 자동 재생

아래로 스와이프
  ├── previousVideoURL 존재 → playPrevious() → 즉시 전환
  └── previousVideoURL 없음 → 무시 (첫 영상)
```

## UI 오버레이

### 닫기 버튼 (좌상단)
- SF Symbol `xmark.circle.fill`
- `dismissPlayer()` 호출 → 웹 브라우저로 복귀

### 영상 인덱스 (우상단)
- 형식: `"currentIndex / total"` (예: "3 / 10")
- `viewModel.currentIndex` / `viewModel.videoURLs.count`

### 영상 제목 (하단)
- `viewModel.currentTitle`에서 가져옴
- 최대 2줄, 그라데이션 배경
- `videoTitles` 딕셔너리에서 현재 URL로 조회

### 프리페치 상태 (중앙)
- `.scrolling` / `.waiting` → ProgressView 스피너
- `.failed` → 실패 메시지

## 화면 전환

웹 브라우저 ↔ 플레이어 전환은 `isPlaying` 상태로 제어:

```
isPlaying = true:
  - WebView opacity → 0 (숨김, 상태 유지)
  - SwipePlayerView 표시
  - Toolbar opacity → 0

isPlaying = false:
  - WebView opacity → 1 (복원)
  - SwipePlayerView 제거
  - Toolbar opacity → 1
```

`opacity` 방식의 이유: WKWebView를 조건부로 제거하면 상태(스크롤, 쿠키, JS 상태)가 리셋됨. `opacity(0)`은 뷰를 유지하면서 시각적으로만 숨깁니다.
