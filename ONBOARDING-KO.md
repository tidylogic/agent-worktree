# Onboarding: Bare Repo + Worktree 구조 이해하기

이 문서는 이 디렉토리의 구조가 낯선 분을 위한 안내서입니다.
"왜 이렇게 되어 있지?"라는 질문에 답합니다.

> English version: [ONBOARDING.md](./ONBOARDING.md)

> **이 문서의 표기 규칙**
> - `<project>` — 실제 레포지토리 이름 (예: `my-api`)
> - `<project-clone-name>` — 이 작업 공간 디렉토리 이름 (예: `my-api-agent-worktree`)
> - `<your-repo-url>` — GitHub 등의 원격 레포지토리 주소

---

## 1. 왜 이 구조를 쓰는가?

### 일반적인 문제

여러 AI 에이전트가 동시에 같은 레포지토리에서 서로 다른 브랜치 작업을 할 때,
보통의 git 레포지토리는 **체크아웃이 하나뿐**이라 충돌이 생깁니다.

```
# 일반 레포지토리에서 에이전트 2개가 동시 작업하면?
Agent A: git checkout feat/#163  ──→  레포 전체가 feat/#163으로 바뀜
Agent B: git checkout AG-1034    ──→  레포 전체가 AG-1034로 바뀜 (A 작업 날아감)
```

### 이 구조의 해결책

**Bare Repo + Worktree** 방식은 브랜치마다 독립된 디렉토리를 만들어 줍니다.

```
Agent A → <project-clone-name>/feat/#163/  (feat/#163 브랜치 전용 공간)
Agent B → <project-clone-name>/AG-1034/   (AG-1034 브랜치 전용 공간)
Agent C → <project-clone-name>/AG-1141/   (AG-1141 브랜치 전용 공간)
```

세 에이전트가 동시에 작업해도 서로 완전히 독립적입니다.

---

## 2. 핵심 개념 두 가지

### Bare Repository (베어 레포지토리)

일반 git 레포지토리는 `.git/` 폴더 + 실제 파일이 함께 있습니다.

```
<project>/
├── .git/         ← git 내부 데이터
├── cmd/
├── domain/
└── ...           ← 실제 코드 파일
```

**베어 레포지토리**는 `.git/` 내부 데이터만 있고, 실제 파일은 없습니다.
즉, git의 "두뇌"만 따로 분리해 놓은 것입니다.

```
<project>.git/   ← git 내부 데이터만 (실제 파일 없음)
├── objects/
├── refs/
├── config
└── ...
```

### Git Worktree (워크트리)

워크트리는 베어 레포지토리에 연결된 "실제 파일이 있는 작업 공간"입니다.
하나의 베어 레포에 워크트리를 여러 개 붙일 수 있고, 각각 다른 브랜치를 가리킵니다.

```
<project>.git  ←─── AG-1034/    (AG-1034 브랜치)
               ←─── AG-1141/    (AG-1141 브랜치)
               ←─── feat/#163/  (feat/#163 브랜치)
```

git 기록과 객체는 `<project>.git` 하나에서 공유하므로, 디스크 공간도 효율적입니다.

---

## 3. 디렉토리 구조

```
agent-worktree/                      ← GitHub 레포 (템플릿, 여기서 Agent 실행)
│
├── .gitignore
├── README.md
├── CLAUDE.md
├── ONBOARDING.md
├── scripts/
│   └── wt.sh                        ← Worktree 관리 스크립트
├── .claude/
│   └── skills/worktree/             ← Agent용 /worktree 스킬
│
└── workspace/                       ← gitignored, 실제 프로젝트 공간
    ├── <project>.git/               ← Bare repo (건드리지 않음)
    └── <branch-name>/               ← 워크트리 (필요할 때 생성, 필요 없으면 제거)
        ├── .git                     ← "이 디렉토리는 워크트리입니다" 포인터 파일
        └── ...                      ← 실제 코드 파일
```

> **참고**: 워크트리 안의 `.git`은 디렉토리가 아닌 **파일**입니다.
> `gitdir: ../<project>.git/worktrees/AG-1034` 같은 내용이 담긴 포인터입니다.

---

## 4. 빠른 시작

### 환경 준비

```bash
# 1. 이 템플릿 클론
git clone https://github.com/tidylogic/agent-worktree
cd agent-worktree

# 2. 스크립트 실행 권한 부여
chmod +x scripts/wt.sh

# 3. 작업할 프로젝트의 bare repo를 workspace/ 안에 추가
git clone --bare <your-repo-url> workspace/<project>.git
```

워크트리는 작업할 브랜치가 생길 때 그때그때 만듭니다.

### 워크트리 생성

```bash
# 기존 브랜치 체크아웃 (브랜치가 이미 있으면 base는 무시됨, 필수 입력)
./scripts/wt.sh create AG-1034 main

# base 기반으로 새 브랜치 + 워크트리 동시 생성
./scripts/wt.sh create feat/#163 AG-1034

cd workspace/<branch-name>
```

---

## 5. 일상적인 워크플로우

### 워크트리 안에서의 git 명령

워크트리 디렉토리 안에서는 **일반 git 레포지토리처럼** 사용하면 됩니다.

```bash
cd workspace/AG-1034

git status
git add domain/clothes.go
git commit -m "[#1034] 옷 조회 API 추가"
git push origin AG-1034
```

베어 레포를 직접 건드릴 필요가 없습니다.

### 워크트리 상태 확인

```bash
./scripts/wt.sh status
```

출력 예시:
```
📁 /path/to/agent-worktree/workspace/AG-1034 [AG-1034]
   ✅ clean
   ✅ remote와 동기화됨

📁 /path/to/agent-worktree/workspace/feat/#163 [feat/#163]
   ⚠  uncommitted 변경 있음
   🔄 remote와 sync 필요
```

### 작업 완료 후 워크트리 제거

```bash
# PR 머지 후 워크트리 정리
./scripts/wt.sh remove AG-1034
```

uncommitted 변경이 있으면 삭제 전에 확인을 요청합니다.

### 주기적인 정리

```bash
# 끊어진 링크 정리 + 머지된 브랜치 탐지
./scripts/wt.sh cleanup
```

---

## 6. wt.sh 명령 정리

| 명령 | 설명 |
|------|------|
| `wt.sh list` | 현재 워크트리 목록 |
| `wt.sh create <branch> <base>` | 워크트리 생성 (브랜치 있으면 체크아웃, 없으면 `<base>` 기반으로 새 브랜치 생성) |
| `wt.sh remove <branch>` | 워크트리 제거 (변경 있으면 확인) |
| `wt.sh status` | 각 워크트리 clean/dirty + sync 상태 |
| `wt.sh cleanup` | prune + 머지 완료 브랜치 탐지 |
| `wt.sh repair` | broken 워크트리 링크 자동 복구 |
| `wt.sh lock <branch>` | 실수 제거 방지 잠금 |
| `wt.sh unlock <branch>` | 잠금 해제 |

---

## 7. AI 에이전트와 함께 쓰기

이 구조의 주요 목적 중 하나는 **AI 에이전트 병렬 실행**입니다.

올바른 워크플로우는 다음과 같습니다:
1. Agent에게 **worktree 생성**을 요청
2. Agent가 생성 후 경로를 알려줌
3. 해당 경로로 이동해 **새 agent 세션을 직접 실행**
4. 새 세션이 해당 디렉토리의 agent 설정을 자동 로드

```bash
# 1-2단계: agent-worktree/ 디렉토리에서 요청
/worktree AG-1034                       → AG-1034 워크트리 준비
/worktree feat/#163 from AG-1034        → AG-1034 기반 새 워크트리 생성

# 3-4단계: worktree 안에서 직접 작업
cd workspace/AG-1034
<agent-cli>                             # 예: claude, codex, gemini, aider, ...
```

**왜 worktree 안에서 직접 실행해야 하나요?**
부모 세션에서 subagent로 위임하면 대상 프로젝트의 설정 파일(`CLAUDE.md`, `AGENTS.md`, 스킬 등)을 자동으로 읽지 않습니다. agent CLI를 worktree 경로에서 직접 실행하면 시작 시 해당 디렉토리의 설정을 읽어 프로젝트 컨텍스트를 올바르게 가져올 수 있습니다.

관리 작업은 `/worktree` 스킬을 사용하세요:

```
/worktree list                          → 목록
/worktree status                        → 전체 상태 점검
/worktree cleanup                       → 불필요한 워크트리 정리
```

---

## 8. 자주 하는 실수

### ❌ bare repo 안에서 파일 편집

```bash
# 잘못된 예
cd agent-worktree/workspace/<project>.git
vim domain/clothes.go  # ← bare repo에는 파일이 없음, 의미 없음
```

항상 워크트리 디렉토리(`AG-1034/`, `feat/#163/` 등)에서 작업하세요.

### ❌ 같은 브랜치로 워크트리 두 개 만들기

하나의 브랜치는 하나의 워크트리만 가질 수 있습니다.

```bash
# 오류 발생
git -C <project>.git worktree add ./AG-1034-copy AG-1034
# fatal: 'AG-1034' is already checked out
```

### ❌ 워크트리 디렉토리를 직접 rm으로 삭제

```bash
# 잘못된 예
rm -rf agent-worktree/workspace/AG-1034/
```

bare repo 내부에 끊어진 링크가 남습니다. 반드시 `wt.sh remove` 또는 `git worktree remove`를 사용하세요.
직접 삭제했다면 `wt.sh repair`로 복구할 수 있습니다.

---

## 9. 핵심 요약

| 개념 | 한 줄 설명                            |
|------|-----------------------------------|
| Bare repo | git 데이터만 있는 "두뇌". 직접 건드리지 않음      |
| Worktree | 브랜치별 독립 작업 공간. 필요할 때 만들고 끝나면 지우면 됨 |
| wt.sh | 워크트리 생성/삭제/점검 도구                  |
| /worktree 스킬 | Agent에게 워크트리 작업을 자연어로 위임하는 명령     |
