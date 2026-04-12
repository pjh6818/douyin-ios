---
title: 알려진 제한사항
category: concept
related: [../overview.md, video-extraction.md, url-handling.md]
sources: [CLAUDE.md, README.md]
---

# 알려진 제한사항

## 외부 의존적 제한

### 1. API 구조 변경
Douyin이 프론트엔드/API를 변경하면 XHR/fetch 인터셉트가 동작하지 않을 수 있음.
- **영향**: Layer 3 (주력 추출) 실패
- **대응**: 새 API 경로/구조에 맞게 JS 업데이트 필요
- **감지**: 웹에서 영상은 보이지만 추출 실패 시

### 2. CDN URL 만료
CDN URL에 만료 타임스탬프 포함. 일반적으로 수 시간 유효.
- **영향**: 장시간 방치 후 재생 실패
- **대응**: 새 URL 재추출 (페이지 새로고침 후 재탐색)

### 3. 로그인 필요 콘텐츠
일부 영상은 로그인 필수.
- **영향**: 해당 영상 접근 불가
- **대응**: WKWebView 내에서 직접 로그인 가능하나 자동화되지 않음

### 4. 새 CDN 도메인
Douyin이 새 CDN 도메인을 추가하면 `isRealVideoURL()`에서 필터링됨.
- **대응**: 새 도메인 패턴을 `isRealVideoURL()`에 추가

## 앱 내부 제한

### 5. 영속성 없음
앱 재시작 시 영상 대기열, 재생 위치, 히스토리 모두 소실.

### 6. 썸네일 미지원
영상 대기열의 미리보기 이미지 없음. 인덱스 번호만으로 구분.

### 7. 검색/필터 없음
추출된 영상을 검색하거나 필터링하는 UI 없음.

### 8. 단일 화질
추출되는 URL의 화질을 선택할 수 없음. `play_addr.url_list[0]`의 첫 번째 URL 사용.

### 9. 오디오 세션 관리 없음
백그라운드 재생, 다른 앱과의 오디오 세션 공유 등 미구현.

### 10. 비공개 API 사용
`AVURLAssetHTTPHeaderFieldsKey`는 비공개 API. App Store 심사 시 거부 가능성.
