# Bare Repo + Worktree Structure

This directory is set up for **parallel agent work** using a bare repository + worktree layout.

## Directory Structure

```
agent-worktree/           ← this git repo (the template on GitHub)
├── .agents/skills/       ← shared agent skills directory
├── .claude/skills/       ← shared agent skills directory (for Claude)
├── scripts/wt.sh         ← worktree manager script
└── workspace/            ← gitignored: bare repo + worktrees live here
    ├── <project>.git/    ← bare repository
    └── <branch-name>/    ← per-branch worktree (e.g. AG-1034/, feat/#163/)
```

## Worktree Rules

### When the user requests a worktree for a specific branch

On requests like "create a worktree for feat/#163" or "set up feat-foo from AG-1034",
**act immediately without asking clarifying questions**:

Derive paths at runtime from the directory containing this file:

```bash
REPO_ROOT=$(pwd)                                                    # directory of this file
WORKTREE_ROOT=$REPO_ROOT/workspace                                  # bare repo + worktrees
BARE_REPO=$(ls -d $WORKTREE_ROOT/*.git 2>/dev/null | head -1)      # auto-detect *.git
```

1. **Check if worktree already exists**
   ```bash
   git -C $BARE_REPO worktree list
   ```

2. **Create worktree if missing**
   - Branch already exists:
     ```bash
     git -C $BARE_REPO worktree add $WORKTREE_ROOT/<branch> <branch>
     ```
   - New branch (`-b` flag):
     ```bash
     git -C $BARE_REPO worktree add -b <new-branch> $WORKTREE_ROOT/<new-branch> <base-branch>
     ```
   - Or use the management script:
     ```bash
     $REPO_ROOT/scripts/wt.sh create <branch> <base>
     ```

3. **Tell the user to open a new agent session in the worktree**
   - Worktree path: `$WORKTREE_ROOT/<branch-name>/`
   - Inform the user: "Worktree is ready. To start working, open a new terminal and run:"
     ```bash
     cd $WORKTREE_ROOT/<branch-name>
     <agent-cli>   # e.g. claude, codex, gemini, aider, ...
     ```
   - The new session will automatically load the project's agent config (`CLAUDE.md`, `AGENTS.md`, `.claude/skills/`, etc.) from that directory.

### Maintenance Commands

| Purpose | Command |
|---------|---------|
| Prune stale links | `git -C $BARE_REPO worktree prune` |
| Recover broken worktree | `git -C $BARE_REPO worktree repair <path>` |
| Lock important worktree | `git -C $BARE_REPO worktree lock --reason "..." <path>` |
| Unlock | `git -C $BARE_REPO worktree unlock <path>` |
| Check all statuses | `scripts/wt.sh status` |
| Detect merged branches | `scripts/wt.sh cleanup` |

### Notes

- Never edit files directly inside the bare repo (`*.git/`)
- Each worktree is fully isolated — uncommitted changes in one don't affect others
- Worktree directory name should match the branch name
- Branch names containing `/` (e.g. `feat/#163`) can be used as-is for nested directory paths
- Use `lock` on long-running worktrees to prevent accidental removal
