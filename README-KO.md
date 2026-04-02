# Bare Repo + Worktree — AI 병렬 작업 환경

> English version: [README.md](./README.md)

여러 LLM 에이전트가 **서로 다른 브랜치에서 동시에** 작업할 수 있도록 bare repository + git worktree로 구성한 템플릿입니다.

```
agent-worktree/
├── scripts/wt.sh        ← worktree 관리 스크립트
├── AGENTS.md           ← Agents 작업 규칙 문서
├── CLAUDE.md           ← Claude 작업 규칙 문서 (심볼릭 링크로 AGENTS.md 참조)
├── .agents/skills/      ← Agents 스킬
├── .claude/skills/      ← Claude 스킬 (심볼릭 링크로 .agents/skills/ 참조)
└── workspace/           ← gitignored, 실제 프로젝트 공간
    ├── <project>.git/   ← bare repo (git 저장소 본체)
    └── <branch-name>/   ← 브랜치별 독립 작업 공간 (worktree)
```

## 빠른 시작

```bash
# 1. 이 템플릿 클론
git clone https://github.com/tidylogic/agent-worktree
cd agent-worktree

# 2. 스크립트 권한 부여
chmod +x scripts/wt.sh

# 3. 작업할 프로젝트의 bare repo를 workspace/ 안에 추가
git clone --bare <your-repo-url> workspace/<project>.git

# 4. 브랜치 worktree 생성 후 작업
./scripts/wt.sh create <branch-name> <base-branch>
cd workspace/<branch-name>
```

## wt.sh 주요 명령

| 명령 | 설명 |
|------|------|
| `wt.sh list` | worktree 목록 |
| `wt.sh create <branch> <base>` | worktree 생성 |
| `wt.sh remove <branch>` | worktree 제거 |
| `wt.sh status` | 전체 clean/dirty + sync 상태 |
| `wt.sh cleanup` | 끊어진 링크 정리 + 머지된 브랜치 탐지 |
| `wt.sh repair` | broken worktree 복구 |

## Agent와 함께 쓰기

이 디렉토리에서 agent CLI를 실행하면 `/worktree` 스킬이 자동으로 로드됩니다.
Agent에게 worktree 생성을 요청하고, 완료 후 직접 해당 경로로 이동해 새 agent 세션을 실행하세요.
새 세션은 해당 프로젝트의 agent 설정(`CLAUDE.md`, `AGENTS.md`, `.claude/skills/` 등)을 자동으로 로드합니다.

```
/worktree feat/#163 from AG-1034        → worktree 생성
/worktree status                        → 전체 상태 점검
```

Worktree 준비가 완료되면:

```bash
cd workspace/<branch-name>
<agent-cli>                             # 예: claude, codex, gemini, aider, ...
```

자세한 내용은 [ONBOARDING-KO.md](./ONBOARDING-KO.md)를 참고하세요.
