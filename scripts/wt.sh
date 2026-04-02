#!/bin/bash
# wt.sh — git worktree manager (bare repo)
# Usage: ./scripts/wt.sh {create|remove|status|cleanup|lock|unlock|repair|list} [branch]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKTREE_ROOT="$REPO_ROOT/workspace"
BARE_REPO=$(ls -d "$WORKTREE_ROOT"/*.git 2>/dev/null | head -1)

# ── Language ────────────────────────────────────────────────────────────────

_read_json() {
    local key=$1
    local file="$REPO_ROOT/settings.json"
    [[ ! -f "$file" ]] && return
    if command -v jq &>/dev/null; then
        jq -r ".$key // empty" "$file" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "import json,sys; d=json.load(open('$file')); print(d.get('$key',''))" 2>/dev/null
    fi
}

LANG_CODE=$(_read_json lang)
[[ -z "$LANG_CODE" ]] && LANG_CODE="en"

if [[ "$LANG_CODE" == "ko" ]]; then
    M_NO_BARE="❌ bare repo (*.git)를 찾을 수 없습니다"
    M_CHECK_WORKSPACE="   workspace/ 디렉토리에 bare repo가 있는지 확인하세요."
    M_EXISTS="이미 존재하는 worktree"
    M_CREATE_EXISTING="기존 브랜치로 worktree 생성"
    M_CREATE_NEW="새 브랜치 생성 후 worktree 추가"
    M_DONE="완료"
    M_HAS_CHANGES="⚠ uncommitted 변경이 있습니다"
    M_FORCE_PROMPT="강제 제거하시겠습니까? (y/N) "
    M_CANCELLED="취소됨"
    M_REMOVED="제거 완료"
    M_DIAGNOSING="🔧 Worktree 진단 및 복구..."
    M_MISSING="❌ 존재하지 않는 worktree"
    M_PRUNE_RUN="→ prune 실행"
    M_DAMAGED="⚠  손상된 worktree"
    M_REPAIR_TRY="→ repair 시도"
    M_HEALTHY="✅ 정상"
    M_FINAL_STATE="최종 상태:"
    M_PRUNING="🧹 불필요한 worktree 정리 중..."
    M_MERGED_HEADER="📋 머지된 브랜치의 worktree:"
    M_MERGED_SUFFIX="— 머지됨 (제거 검토)"
    M_LOCKED="잠금 완료"
    M_UNLOCKED="잠금 해제"
    M_UNCOMMITTED="⚠  uncommitted 변경 있음"
    M_CLEAN="✅ clean"
    M_SYNC_NEEDED="🔄 remote와 sync 필요"
    M_SYNCED="✅ remote와 동기화됨"
    M_BROKEN="❌ 디렉토리 없음 (broken)"
    HELP_LIST="현재 worktree 목록"
    HELP_CREATE="worktree 생성 (브랜치 없으면 <base> 기반 신규 생성)"
    HELP_REMOVE="worktree 제거 (uncommitted 변경 시 확인)"
    HELP_STATUS="각 worktree의 clean/dirty 및 sync 상태"
    HELP_CLEANUP="prune + 머지된 브랜치 탐지"
    HELP_REPAIR="broken worktree 링크 복구"
    HELP_LOCK="worktree 잠금 (실수 제거 방지)"
    HELP_UNLOCK="worktree 잠금 해제"
else
    M_NO_BARE="❌ bare repo (*.git) not found"
    M_CHECK_WORKSPACE="   Make sure a bare repo exists in the workspace/ directory."
    M_EXISTS="Worktree already exists"
    M_CREATE_EXISTING="Creating worktree from existing branch"
    M_CREATE_NEW="Creating new branch and worktree"
    M_DONE="Done"
    M_HAS_CHANGES="⚠ Uncommitted changes in"
    M_FORCE_PROMPT="Force remove? (y/N) "
    M_CANCELLED="Cancelled"
    M_REMOVED="Removed"
    M_DIAGNOSING="🔧 Diagnosing and repairing worktrees..."
    M_MISSING="❌ Missing worktree"
    M_PRUNE_RUN="→ running prune"
    M_DAMAGED="⚠  Damaged worktree"
    M_REPAIR_TRY="→ attempting repair"
    M_HEALTHY="✅ Healthy"
    M_FINAL_STATE="Final state:"
    M_PRUNING="🧹 Pruning stale worktrees..."
    M_MERGED_HEADER="📋 Worktrees with merged branches:"
    M_MERGED_SUFFIX="— merged (consider removing)"
    M_LOCKED="Locked"
    M_UNLOCKED="Unlocked"
    M_UNCOMMITTED="⚠  Uncommitted changes"
    M_CLEAN="✅ Clean"
    M_SYNC_NEEDED="🔄 Out of sync with remote"
    M_SYNCED="✅ In sync with remote"
    M_BROKEN="❌ Directory missing (broken)"
    HELP_LIST="List all worktrees"
    HELP_CREATE="Create worktree (new branch from <base> if branch doesn't exist)"
    HELP_REMOVE="Remove worktree (prompts if uncommitted changes)"
    HELP_STATUS="Show clean/dirty and sync status for each worktree"
    HELP_CLEANUP="Prune stale links and detect merged branches"
    HELP_REPAIR="Recover broken worktree links"
    HELP_LOCK="Lock worktree to prevent accidental removal"
    HELP_UNLOCK="Unlock worktree"
fi

# ── Validation ───────────────────────────────────────────────────────────────

if [[ -z "$BARE_REPO" ]]; then
    echo "$M_NO_BARE: $WORKTREE_ROOT"
    echo "$M_CHECK_WORKSPACE"
    exit 1
fi

# ── Colors ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Commands ─────────────────────────────────────────────────────────────────

create_worktree() {
    local branch=$1
    local base=$2
    local path="${WORKTREE_ROOT}/${branch}"

    if git -C "$BARE_REPO" worktree list | grep -q "$path"; then
        echo -e "${YELLOW}${M_EXISTS}:${NC} $path"
        return 0
    fi

    if git -C "$BARE_REPO" show-ref --verify --quiet "refs/heads/$branch"; then
        echo -e "${BLUE}${M_CREATE_EXISTING}:${NC} $branch"
        git -C "$BARE_REPO" worktree add "$path" "$branch"
    else
        echo -e "${BLUE}${M_CREATE_NEW}:${NC} $branch (base: $base)"
        git -C "$BARE_REPO" worktree add -b "$branch" "$path" "$base"
    fi

    echo -e "${GREEN}${M_DONE}:${NC} $path"
}

remove_worktree() {
    local branch=$1
    local path="${WORKTREE_ROOT}/${branch}"

    if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
        echo -e "${YELLOW}${M_HAS_CHANGES}: $path${NC}"
        echo -n "$M_FORCE_PROMPT"
        read -r answer
        [[ "$answer" =~ ^[Yy]$ ]] || { echo "$M_CANCELLED"; return 1; }
        git -C "$BARE_REPO" worktree remove --force "$path"
    else
        git -C "$BARE_REPO" worktree remove "$path"
    fi

    echo -e "${GREEN}${M_REMOVED}:${NC} $path"
}

status_worktrees() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              Git Worktree Status                         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    git -C "$BARE_REPO" worktree list | while IFS= read -r line; do
        path=$(echo "$line" | awk '{print $1}')
        branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\]/\1/p')
        [[ -z "$branch" ]] && branch="(detached)"

        echo -e "${YELLOW}📁 $path${NC} [$branch]"

        if [[ -d "$path" ]]; then
            if [[ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]]; then
                echo -e "   ${YELLOW}${M_UNCOMMITTED}${NC}"
            else
                echo -e "   ${GREEN}${M_CLEAN}${NC}"
            fi

            local_ref=$(git -C "$path" rev-parse HEAD 2>/dev/null)
            remote_ref=$(git -C "$BARE_REPO" rev-parse "origin/$branch" 2>/dev/null)
            if [[ -n "$remote_ref" && "$local_ref" != "$remote_ref" ]]; then
                echo -e "   ${YELLOW}${M_SYNC_NEEDED}${NC}"
            elif [[ -n "$remote_ref" ]]; then
                echo -e "   ${GREEN}${M_SYNCED}${NC}"
            fi
        else
            echo -e "   ${RED}${M_BROKEN}${NC}"
        fi
    done
}

cleanup_worktrees() {
    echo "$M_PRUNING"
    git -C "$BARE_REPO" worktree prune -v

    echo ""
    echo "$M_MERGED_HEADER"
    git -C "$BARE_REPO" worktree list | while IFS= read -r line; do
        path=$(echo "$line" | awk '{print $1}')
        branch=$(echo "$line" | sed -n 's/.*\[\(.*\)\]/\1/p')

        if [[ -n "$branch" ]]; then
            if git -C "$BARE_REPO" branch -r --merged "origin/HEAD" 2>/dev/null | grep -q "$branch"; then
                echo -e "  ${YELLOW}→ $path [$branch]${NC} ${M_MERGED_SUFFIX}"
            fi
        fi
    done
}

repair_worktrees() {
    echo "$M_DIAGNOSING"

    git -C "$BARE_REPO" worktree list | while IFS= read -r line; do
        path=$(echo "$line" | awk '{print $1}')

        if [[ ! -d "$path" ]]; then
            echo -e "${RED}${M_MISSING}:${NC} $path ${M_PRUNE_RUN}"
            git -C "$BARE_REPO" worktree prune -v
        elif [[ ! -f "$path/.git" ]]; then
            echo -e "${YELLOW}${M_DAMAGED}:${NC} $path ${M_REPAIR_TRY}"
            git -C "$BARE_REPO" worktree repair "$path"
        else
            echo -e "${GREEN}${M_HEALTHY}:${NC} $path"
        fi
    done

    echo ""
    echo "$M_FINAL_STATE"
    git -C "$BARE_REPO" worktree list
}

# ── Dispatch ─────────────────────────────────────────────────────────────────

case $1 in
    "create"|"c")
        [[ -z $2 ]] && { echo "Usage: $0 create <branch> <base-branch>"; exit 1; }
        [[ -z $3 ]] && { echo "Usage: $0 create <branch> <base-branch>"; exit 1; }
        create_worktree "$2" "$3"
        ;;
    "remove"|"rm")
        [[ -z $2 ]] && { echo "Usage: $0 remove <branch>"; exit 1; }
        remove_worktree "$2"
        ;;
    "status"|"s")
        status_worktrees
        ;;
    "cleanup"|"clean")
        cleanup_worktrees
        ;;
    "repair")
        repair_worktrees
        ;;
    "lock")
        [[ -z $2 ]] && { echo "Usage: $0 lock <branch> [reason]"; exit 1; }
        reason=${3:-"locked"}
        git -C "$BARE_REPO" worktree lock --reason "$reason" "${WORKTREE_ROOT}/$2"
        echo -e "${GREEN}${M_LOCKED}:${NC} $2"
        ;;
    "unlock")
        [[ -z $2 ]] && { echo "Usage: $0 unlock <branch>"; exit 1; }
        git -C "$BARE_REPO" worktree unlock "${WORKTREE_ROOT}/$2"
        echo -e "${GREEN}${M_UNLOCKED}:${NC} $2"
        ;;
    "list"|"l"|"")
        git -C "$BARE_REPO" worktree list
        ;;
    *)
        echo "wt.sh — worktree manager"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        printf "  %-30s %s\n" "list"                        "$HELP_LIST"
        printf "  %-30s %s\n" "create <branch> <base>"      "$HELP_CREATE"
        printf "  %-30s %s\n" "remove <branch>"             "$HELP_REMOVE"
        printf "  %-30s %s\n" "status"                      "$HELP_STATUS"
        printf "  %-30s %s\n" "cleanup"                     "$HELP_CLEANUP"
        printf "  %-30s %s\n" "repair"                      "$HELP_REPAIR"
        printf "  %-30s %s\n" "lock <branch> [reason]"      "$HELP_LOCK"
        printf "  %-30s %s\n" "unlock <branch>"             "$HELP_UNLOCK"
        ;;
esac
