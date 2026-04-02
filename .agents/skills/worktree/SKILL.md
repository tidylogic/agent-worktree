---
name: worktree
description: "Bare repo 기반 worktree를 생성·확인·삭제·복구합니다. 특정 브랜치에서 작업 준비를 할 때 사용하세요."
---

# Worktree 관리 스킬

## 경로 도출

Agent는 이 스킬을 실행할 때 아래 명령으로 경로를 결정한다 (특별한 설정 불필요):

```bash
REPO_ROOT=$(pwd)                                                          # Agent 실행 위치 (레포 루트)
WORKTREE_ROOT=$REPO_ROOT/workspace                                        # bare repo + worktree 공간
BARE_REPO=$(ls -d $WORKTREE_ROOT/*.git 2>/dev/null | head -1)            # *.git 자동 탐지
WTS=$REPO_ROOT/scripts/wt.sh
```

## 서브커맨드

### `/worktree` 또는 `/worktree list`
현재 등록된 worktree 목록을 보여준다.
```bash
git -C $BARE_REPO worktree list
```

### `/worktree <branch-name>`
해당 브랜치의 worktree를 준비하고 경로를 알려준다.

1. worktree 목록에서 이미 있는지 확인
2. **있으면**: 경로를 알려주고 끝
3. **없으면**: 브랜치 존재 여부에 따라 생성
   ```bash
   # 기존 브랜치 → worktree 추가
   git -C $BARE_REPO worktree add $WORKTREE_ROOT/<branch> <branch>

   # 새 브랜치 → base 브랜치를 사용자에게 확인 후 생성
   git -C $BARE_REPO worktree add -b <branch> $WORKTREE_ROOT/<branch> <base-branch>
   ```
4. 생성된 worktree 경로 출력

### `/worktree <new-branch> from <base-branch>`
`<base-branch>`에서 분기한 새 브랜치 worktree를 만든다.
```bash
git -C $BARE_REPO worktree add -b <new-branch> $WORKTREE_ROOT/<new-branch> <base-branch>
```

### `/worktree remove <branch-name>`
worktree를 안전하게 제거한다. uncommitted 변경이 있으면 사용자에게 확인한다.
```bash
# 안전 제거 (uncommitted 변경 있으면 실패)
git -C $BARE_REPO worktree remove $WORKTREE_ROOT/<branch>

# 강제 제거 — 사용자 명시적 확인 후에만
git -C $BARE_REPO worktree remove --force $WORKTREE_ROOT/<branch>
```

### `/worktree status`
각 worktree의 clean/dirty 상태와 remote sync 상태를 보여준다.
```bash
git -C $BARE_REPO worktree list | while IFS= read -r line; do
    path=$(echo "$line" | awk '{print $1}')
    branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\]/\1/p')

    echo "📁 $path [$branch]"

    # uncommitted 변경 확인
    if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
        echo "   ⚠  uncommitted 변경 있음"
    else
        echo "   ✅ clean"
    fi

    # remote sync 확인
    local_ref=$(git -C "$path" rev-parse HEAD 2>/dev/null)
    remote_ref=$(git -C "$BARE_REPO" rev-parse "origin/$branch" 2>/dev/null)
    if [[ -n "$remote_ref" && "$local_ref" != "$remote_ref" ]]; then
        echo "   🔄 remote와 sync 필요"
    fi
done
```

### `/worktree cleanup`
끊어진 링크를 정리하고 이미 머지된 브랜치의 worktree를 탐지한다.
```bash
# 끊어진 링크 정리
git -C $BARE_REPO worktree prune -v

# 머지된 브랜치 탐지 (각 워크트리를 기준 브랜치와 비교)
git -C $BARE_REPO worktree list | while IFS= read -r line; do
    path=$(echo "$line" | awk '{print $1}')
    branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\]/\1/p')
    if [[ -n "$branch" ]]; then
        # 원격에서 머지된 브랜치 확인
        if git -C "$BARE_REPO" branch -r --merged "origin/HEAD" 2>/dev/null | grep -q "$branch"; then
            echo "→ $path [$branch] — 머지됨 (제거 검토)"
        fi
    fi
done
```

### `/worktree repair`
broken worktree 링크를 자동으로 탐지하고 복구한다.
```bash
git -C $BARE_REPO worktree list | while IFS= read -r line; do
    path=$(echo "$line" | awk '{print $1}')
    if [[ ! -d "$path" ]]; then
        echo "❌ 없는 경로: $path → prune"
        git -C "$BARE_REPO" worktree prune -v
    elif [[ ! -f "$path/.git" ]]; then
        echo "⚠  손상됨: $path → repair"
        git -C "$BARE_REPO" worktree repair "$path"
    fi
done
```

### `/worktree lock <branch-name> [reason]`
worktree를 잠가 실수로 제거되지 않도록 보호한다. 장기 작업이나 production hotfix에 사용.
```bash
git -C $BARE_REPO worktree lock --reason "<reason>" $WORKTREE_ROOT/<branch>
```

### `/worktree unlock <branch-name>`
```bash
git -C $BARE_REPO worktree unlock $WORKTREE_ROOT/<branch>
```

## 관리 스크립트

위 모든 동작을 래핑한 셸 스크립트가 있다:
```bash
$WTS {list|create|remove|status|cleanup|repair|lock|unlock} [branch] [base]
```

## 명시적 호출 없이도 적용되는 규칙

사용자가 `/worktree`를 호출하지 않더라도, 특정 브랜치의 worktree 생성 요청이 오면
이 스킬의 로직을 내재화하여 worktree를 자동으로 준비한 후 경로를 안내한다.

예시 트리거:
- "AG-163 브랜치 worktree 만들어줘"
- "feat/#163 브랜치 만들어줘, AG-1034 기반으로"
- "hotfix 브랜치 잠가줘" → `/worktree lock`
- "worktree 상태 보여줘" → `/worktree status`

## Worktree 준비 후 안내 규칙

worktree 생성이 완료되면 **반드시 사용자에게 아래 안내를 전달**한다:

```
Worktree가 준비됐습니다.
새 터미널에서 아래 명령으로 작업을 시작하세요:

  cd $WORKTREE_ROOT/<branch-name>
  <agent-cli>   # 예: claude, codex, gemini, aider, ...

해당 디렉토리에서 agent CLI를 실행하면 프로젝트의 CLAUDE.md, AGENTS.md, .claude/skills/ 등
agent 설정이 자동으로 로드됩니다.
```

> **이유**: 현재 세션에서 subagent로 작업을 위임하면 대상 프로젝트의 설정 파일(CLAUDE.md, AGENTS.md, 스킬 등)을 자동으로 읽지 않는다. worktree 경로에서 agent CLI를 직접 실행하는 것이 프로젝트 컨텍스트를 올바르게 가져오는 유일한 방법이다.
