---
title: 디버깅 가이드
category: guide
related: [../concepts/video-extraction.md, ../concepts/url-handling.md, ../concepts/js-swift-bridge.md]
sources: [모든 파일]
---

# 디버깅 가이드

## 로그 확인

모든 로그는 `os_log`로 `[DouyinPlayer]` 접두사 출력. Xcode 콘솔에서 필터링:

```
[DouyinPlayer]
```

### 주요 로그 포인트

| 위치 | 로그 내용 |
|------|----------|
| JS 메시지 수신 | `visibleVideo`, `videoInfoList` 등 메시지 타입과 값 |
| URL 저장 | 대기열에 추가되는 URL |
| 재생 시작 | `playURL()` 호출 시 URL과 헤더 |
| 프리페치 | 트리거, 성공, 실패, 타임아웃 |
| 네비게이션 | 페이지 전환, JS 재주입 |

## 흔한 문제와 해결

### 1. 영상이 검출되지 않음

**증상**: 웹에서 영상은 보이지만 ▶ 버튼이 회색

**원인 후보**:
- Douyin이 API 구조를 변경함
- JavaScript 주입이 실패함
- 새로운 CDN 도메인 사용

**진단**:
1. Safari Web Inspector 연결 (Develop → Simulator)
2. JS 콘솔에서 `__douyinNetworkHooked`, `__douyinDOMInstalled` 확인
3. Network 탭에서 API 응답 구조 확인
4. `isRealVideoURL()` 함수에 새 도메인 추가 필요 여부 확인

### 2. 403 Forbidden 재생 에러

**증상**: URL은 추출되지만 재생 시 검정 화면

**원인**: Referer 헤더 누락 또는 잘못된 값

**진단**:
1. `playURL()`의 `AVURLAsset` 옵션 확인
2. `Referer: https://www.douyin.com/` 헤더가 설정되어 있는지 확인
3. Safari에서 URL을 직접 열어 테스트 (개발자 도구 → Network)

### 3. blob: URL만 감지됨

**증상**: 로그에 `blob:` URL만 나타남

**원인**: MSE 기반 재생이 주력이 된 경우. XHR/fetch 인터셉트가 작동하지 않음

**진단**:
1. `networkInterceptScript`의 API 경로 패턴 확인
2. Douyin이 새 API 엔드포인트를 사용하는지 확인
3. `findAllVideoInfo()`의 재귀 탐색이 `play_addr` 구조에 도달하는지 확인

### 4. 프리페치 실패

**증상**: 스와이프 시 "로드 실패" 표시

**원인**: 피드 API 변경 또는 인증 문제

**진단**:
1. `scrollToLoadMoreScript`의 API URL과 파라미터 확인
2. Safari Web Inspector에서 직접 API 호출 테스트
3. 쿠키/세션 문제 확인

### 5. WKWebView가 플레이어 위에 표시됨

**증상**: 재생 시 웹페이지가 플레이어를 가림

**원인**: WKWebView의 컴포지팅 레이어 이슈

**확인**: `opacity(0)` 바인딩이 `isPlaying`에 올바르게 연결되어 있는지 확인

## Safari Web Inspector 연결

시뮬레이터에서 실행 시:
1. Safari → Develop 메뉴 활성화 (Preferences → Advanced)
2. Develop → Simulator → 앱의 WKWebView 선택
3. Console, Network, Elements 탭으로 JS 동작 확인 가능

## 빌드 명령

```bash
xcodebuild build \
  -project DouyinPlayerApp.xcodeproj \
  -scheme DouyinPlayerApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```
