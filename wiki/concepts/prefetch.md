---
title: 프리페치 시스템
category: concept
related: [../components/douyin-player-viewmodel.md, ../components/douyin-javascript.md, swipe-player.md]
sources: [DouyinPlayerViewModel.swift, DouyinJavaScript.swift]
---

# 프리페치 시스템

사용자가 영상을 스와이프할 때 끊김 없이 다음 영상을 재생하기 위한 선제적 로딩 메커니즘.

## 상태 머신

```
    ┌─────────┐
    │  idle   │ ← 초기 상태
    └────┬────┘
         │ triggerPrefetch()
         ▼
    ┌──────────┐
    │ scrolling│ ← JS 스크립트 실행 중
    └────┬─────┘
         │ (API 호출 진행)
         ▼
    ┌──────────┐
    │ waiting  │ ← 응답 대기
    └────┬─────┘
         │
    ┌────┴────┐
    ▼         ▼
 ┌──────┐ ┌────────┐
 │ idle │ │ failed │
 └──────┘ └────────┘
 (성공)    (타임아웃/에러)
```

## 트리거 조건

### 1. 수동 트리거 (사용자 스와이프)
대기열 끝에서 위로 스와이프 시:
- `playNext()`에서 `nextVideoURL == nil` 감지
- `pendingAutoPlayNext = true` 설정
- `triggerPrefetch()` 호출

### 2. 선제적 트리거 (자동)
영상 재생 시작 시 `checkProactivePrefetch()` 호출:
- 현재 위치에서 남은 영상이 2개 이하 → 자동 프리페치
- 사용자가 끝에 도달하기 전에 미리 로드

## 프리페치 API 호출

`scrollToLoadMoreScript`가 Douyin 피드 API를 직접 호출:

```
GET https://www.douyin.com/aweme/v1/web/tab/feed/
    ?device_platform=webapp
    &aid=6383
    &channel=channel_pc_web
    &count=10
    &...
```

### 페이지네이션
- `__douyinFeedState` 전역 객체에 커서 저장
- 첫 호출: 커서 없이 요청
- 이후 호출: 이전 응답의 `cursor` 값 사용
- `has_more` 플래그로 추가 데이터 존재 확인

## 타임아웃

8초 타이머 (`prefetchTimer`):
- `triggerPrefetch()` 시 시작
- 시간 내 `videoInfoList` 메시지 미수신 → `handlePrefetchFailure()`
- 메시지 수신 시 타이머 취소

## 자동 재생 연결

`pendingAutoPlayNext` 플래그가 설정된 경우:
1. 프리페치 완료 → `resolvePendingPrefetch()` 호출
2. 새 영상이 대기열에 추가된 상태
3. `playNext()` 호출 → 자동으로 다음 영상 재생

사용자 입장에서는 "끝에서 스와이프 → 잠시 로딩 → 새 영상 자동 재생" 경험.

## UI 피드백

`SwipePlayerView`에서 프리페치 상태를 시각적으로 표시:
- `.scrolling` / `.waiting`: ProgressView + "다음 영상 로딩 중..." 텍스트
- `.failed`: "로드 실패" 메시지 (일시적으로 표시)
