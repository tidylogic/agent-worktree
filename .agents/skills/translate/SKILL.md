---
name: translate
description: "문서를 한국어↔영어로 번역합니다. 파일명 규칙({name}.md = 영어, {name}-KO.md = 한국어)을 자동으로 적용합니다."
---

# 문서 번역 스킬

## 파일명 규칙

| 파일 | 언어 |
|------|------|
| `{name}.md` | 영어 (기준) |
| `{name}-KO.md` | 한국어 |

## 사용 패턴

### `/translate {file}`

인자로 받은 파일을 읽고, 반대 언어로 번역해 쌍을 이루는 파일에 저장한다.

- `ONBOARDING-KO.md` → 영어로 번역 → `ONBOARDING.md` 덮어쓰기
- `ONBOARDING.md` → 한국어로 번역 → `ONBOARDING-KO.md` 덮어쓰기
- `README-KO.md` → 영어로 번역 → `README.md` 덮어쓰기
- (그 외 패턴도 동일하게 적용)

## 실행 절차

1. **방향 판별**: 파일명이 `-KO.md`로 끝나면 KO→EN, 아니면 EN→KO
2. **원본 파일 읽기**
3. **번역 수행**
   - 코드 블록(` ``` ` 내부) 및 명령어는 번역하지 않음
   - 주석(`←`, `#`) 안의 설명은 번역
   - 기술 용어(worktree, bare repo, branch 등)는 영어 그대로 유지
   - 마크다운 구조(헤더, 표, 목록) 그대로 유지
4. **AI 번역 고지 추가**: 영어 파일에만 다음 블록을 제목 바로 아래에 삽입
    ```
    > 🤖 AI translated This document.
    > The original is written in Korean: [{name}-KO.md](./{name}-KO.md)
    ```
   한국어 파일에는 삽입하지 않음 (한국어가 원문이므로)
5. **대상 파일 저장**: 기존 파일이 있으면 덮어씀

## 주의사항

- 번역 전에 반드시 원본 파일을 읽어 전체 내용을 파악한 후 번역
- 부분 번역 금지 — 파일 전체를 한 번에 번역
- `settings.json`의 `lang` 설정과 무관하게 동작 (번역 방향은 파일명으로만 결정)
