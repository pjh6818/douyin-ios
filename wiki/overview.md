---
title: 프로젝트 개요
category: overview
related: [architecture.md, concepts/video-extraction.md]
sources: [App.swift, README.md, CLAUDE.md]
---

# Douyin iOS Player - 프로젝트 개요

## 한줄 요약

Douyin(抖音) 웹페이지를 WKWebView로 로드하고, JavaScript 인젝션으로 영상 CDN URL을 추출하여 AVPlayer로 네이티브 재생하는 iOS SwiftUI 앱.

## 왜 이 앱이 필요한가

Douyin 웹 플레이어는 MediaSource Extensions(MSE)를 사용하여 `blob:` URL로 영상을 재생합니다. `blob:` URL은 브라우저 메모리에서만 유효하므로 네이티브 플레이어로 직접 재생할 수 없습니다. 이 앱은 JavaScript를 주입하여 실제 CDN URL을 가로채고, 이를 AVPlayer에서 직접 재생합니다.

## 핵심 가치

| 특성 | 설명 |
|------|------|
| **네이티브 재생** | AVPlayer 기반. 하드웨어 가속, 배터리 효율 |
| **워터마크 제거** | `/playwm/` → `/play/` URL 치환 |
| **스와이프 탐색** | TikTok 스타일 상하 스와이프로 영상 전환 |
| **프리페치** | 대기열 영상이 2개 이하일 때 자동으로 다음 영상 로드 |
| **제로 의존성** | SwiftUI + WebKit + AVFoundation만 사용. 외부 라이브러리 없음 |

## 기술 스택

- **언어**: Swift 5.0
- **UI**: SwiftUI (iOS 17.0+)
- **웹 렌더링**: WKWebView (WebKit)
- **미디어 재생**: AVFoundation (AVPlayer + AVURLAsset)
- **빌드**: Xcode 16, xcodebuild

## 대상 플랫폼

- iOS 17.0+
- iPhone + iPad
- 번들 ID: `com.example.DouyinPlayerApp`
