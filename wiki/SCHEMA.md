# Douyin iOS Wiki Schema

## 목적

이 위키는 douyin-ios 코드베이스의 지식을 구조화하여, 새로운 개발자나 미래의 LLM 세션이 프로젝트를 빠르게 이해하고 작업할 수 있도록 합니다.

## 디렉토리 구조

```
wiki/
├── SCHEMA.md           ← 이 파일. 위키 운영 규칙
├── index.md            ← 전체 페이지 목록 + 한줄 요약
├── log.md              ← 위키 변경 이력 (append-only)
├── overview.md         ← 프로젝트 전체 개요
├── architecture.md     ← 아키텍처 + 데이터 흐름
├── components/         ← 파일/컴포넌트별 상세 페이지
├── concepts/           ← 핵심 개념 설명 (JS 인젝션, CDN 등)
└── guides/             ← 작업 가이드 (디버깅, 확장 등)
```

## 페이지 형식

모든 페이지는 마크다운. 상단에 메타데이터:

```markdown
---
title: 페이지 제목
category: component | concept | guide | overview
related: [관련 페이지 링크들]
sources: [원본 소스 파일 경로들]
---
```

## 링크 규칙

- 위키 내부 링크: `[표시텍스트](상대경로.md)`
- 소스 코드 참조: `파일명:라인번호` 형식
- 외부 링크: 전체 URL

## 업데이트 규칙

1. 소스 코드 변경 시 관련 위키 페이지도 업데이트
2. 새 페이지 생성 시 index.md에 항목 추가
3. 모든 변경은 log.md에 기록
4. 교차 참조(related) 양방향 유지
