# Bare Repo + Worktree 구조

이 디렉토리는 **병렬 agent 작업**을 위해 bare repository + worktree 방식으로 구성되어 있습니다.

## 디렉토리 구조

```
agent-worktree/           ← 이 git 레포 (GitHub에 올라가는 템플릿)
├── .agents/skills/       ← 공유 Agents 스킬 디렉토리
├── .claude/skills/       ← 공유 Agent 스킬 디렉토리 (Claude용)
├── scripts/wt.sh         ← worktree 관리 스크립트
└── workspace/            ← gitignored, 실제 프로젝트 공간
    ├── <project>.git/    ← bare repository (git 저장소 본체)
    └── <branch-name>/    ← 각 브랜치의 worktree (예: AG-1034/, feat/#163/)
```

## Worktree 작업 규칙

### 사용자가 특정 브랜치의 worktree 생성을 요청할 때

"feat/#163 worktree 만들어줘", "feat-foo를 AG-1034 기반으로 생성해줘" 같은 요청을 받으면
**되묻지 않고** 아래 절차를 바로 실행한다:

경로는 이 파일이 있는 디렉토리를 기준으로 런타임에 도출한다:

```bash
REPO_ROOT=$(pwd)                                                    # 이 파일이 있는 디렉토리
WORKTREE_ROOT=$REPO_ROOT/workspace                                  # bare repo + worktree 공간
BARE_REPO=$(ls -d $WORKTREE_ROOT/*.git 2>/dev/null | head -1)      # *.git 자동 탐지
```

1. **worktree 존재 확인**
   ```bash
   git -C $BARE_REPO worktree list
   ```

2. **worktree가 없으면 생성**
   - 브랜치가 이미 존재하는 경우:
     ```bash
     git -C $BARE_REPO worktree add $WORKTREE_ROOT/<branch> <branch>
     ```
   - 브랜치를 새로 만드는 경우 (`-b` 플래그):
     ```bash
     git -C $BARE_REPO worktree add -b <new-branch> $WORKTREE_ROOT/<new-branch> <base-branch>
     ```
   - 또는 관리 스크립트 사용:
     ```bash
     $REPO_ROOT/scripts/wt.sh create <branch> <base>
     ```

3. **사용자에게 새 agent 세션을 열도록 안내**
   - worktree 경로: `$WORKTREE_ROOT/<branch-name>/`
   - 사용자에게 전달: "Worktree가 준비됐습니다. 새 터미널에서 아래 명령으로 작업을 시작하세요:"
     ```bash
     cd $WORKTREE_ROOT/<branch-name>
     <agent-cli>   # 예: claude, codex, gemini, aider, ...
     ```
   - 새 세션은 해당 디렉토리의 agent 설정(`CLAUDE.md`, `AGENTS.md`, `.claude/skills/` 등)을 자동으로 로드합니다.

### 유지보수 명령

| 목적 | 명령 |
|------|------|
| 끊어진 링크 정리 | `git -C $BARE_REPO worktree prune` |
| broken worktree 복구 | `git -C $BARE_REPO worktree repair <path>` |
| 중요 worktree 잠금 | `git -C $BARE_REPO worktree lock --reason "..." <path>` |
| 잠금 해제 | `git -C $BARE_REPO worktree unlock <path>` |
| 전체 상태 확인 | `scripts/wt.sh status` |
| 머지된 브랜치 탐지 | `scripts/wt.sh cleanup` |

### 주의사항

- bare repo(`*.git/`) 내부에서 직접 파일 편집 금지
- 각 worktree는 독립된 작업 공간 — 다른 worktree의 uncommitted 변경에 영향 없음
- worktree 이름은 브랜치 이름과 동일하게 유지
- 슬래시(`/`) 포함 브랜치명(예: `feat/#163`)은 그대로 디렉토리 경로로 사용 가능
- 장기 작업 worktree는 `lock`으로 실수 제거 방지
