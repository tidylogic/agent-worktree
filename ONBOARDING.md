# Onboarding: Understanding the Bare Repo + Worktree Structure

> 🤖 AI translated This document.
> The original is written in Korean: [ONBOARDING-KO.md](./ONBOARDING-KO.md)

This guide is for anyone unfamiliar with this directory layout.
It answers the question: "Why is it set up this way?"

> **Notation used in this document**
> - `<project>` — your repository name (e.g. `my-api`)
> - `<project-clone-name>` — the name of this workspace directory (e.g. `my-api-agent-worktree`)
> - `<your-repo-url>` — the remote URL of your Git repository

---

## 1. Why this structure?

### The problem

When multiple AI agents work on different branches of the same repository simultaneously,
a normal git repo has **only one checkout** — causing conflicts.

```
# Two agents working at the same time on a normal repo:
Agent A: git checkout feat/#163  ──→  entire repo switches to feat/#163
Agent B: git checkout AG-1034    ──→  entire repo switches to AG-1034 (A's work is gone)
```

### The solution

The **Bare Repo + Worktree** approach gives each branch its own independent directory.

```
Agent A → <project-clone-name>/feat/#163/  (exclusive workspace for feat/#163)
Agent B → <project-clone-name>/AG-1034/   (exclusive workspace for AG-1034)
Agent C → <project-clone-name>/AG-1141/   (exclusive workspace for AG-1141)
```

All three agents work simultaneously with zero interference.

---

## 2. Two key concepts

### Bare Repository

A normal git repo has a `.git/` folder alongside the actual files.

```
<project>/
├── .git/         ← git internals
├── cmd/
├── domain/
└── ...           ← source files
```

A **bare repository** contains only the git internals — no working files.
Think of it as the "brain" of git, separated out on its own.

```
<project>.git/   ← git internals only (no source files)
├── objects/
├── refs/
├── config
└── ...
```

### Git Worktree

A worktree is a working directory linked to a bare repository.
One bare repo can have multiple worktrees, each pointing to a different branch.

```
<project>.git  ←─── AG-1034/    (branch AG-1034)
               ←─── AG-1141/    (branch AG-1141)
               ←─── feat/#163/  (branch feat/#163)
```

All worktrees share the same git history and objects, so disk usage stays efficient.

---

## 3. Directory structure

```
agent-worktree/                      ← this git repo (template, run Agent from here)
│
├── .gitignore
├── README.md
├── CLAUDE.md
├── ONBOARDING.md
├── scripts/
│   └── wt.sh                        ← worktree manager script
├── .claude/
│   └── skills/worktree/             ← /worktree skill for Agent
│
└── workspace/                       ← gitignored: your actual project
    ├── <project>.git/               ← bare repo (do not edit directly)
    └── <branch-name>/               ← worktree (create when needed, delete when done)
        ├── .git                     ← pointer file: "this directory is a worktree"
        └── ...                      ← source files
```

> **Note**: The `.git` inside a worktree is a **file**, not a directory.
> It contains a pointer like `gitdir: ../<project>.git/worktrees/AG-1034`.

---

## 4. Quick Start

### Setup

```bash
# 1. Clone this template
git clone https://github.com/tidylogic/agent-worktree
cd agent-worktree

# 2. Make the script executable
chmod +x scripts/wt.sh

# 3. Add your project as a bare repo inside workspace/
git clone --bare <your-repo-url> workspace/<project>.git
```

Worktrees are created on demand — only when you need to work on a branch.

### Create a worktree

```bash
# Check out an existing branch (base is required but ignored if branch already exists)
./scripts/wt.sh create AG-1034 main

# Create a new branch from base, with its own worktree
./scripts/wt.sh create feat/#163 AG-1034

cd workspace/<branch-name>
```

---

## 5. Daily workflow

### Git commands inside a worktree

Inside a worktree directory, use git **exactly like a normal repository**.

```bash
cd workspace/AG-1034

git status
git add domain/clothes.go
git commit -m "[#1034] Add clothes query API"
git push origin AG-1034
```

No need to touch the bare repo directly.

### Check worktree status

```bash
./scripts/wt.sh status
```

Example output:
```
📁 /path/to/agent-worktree/workspace/AG-1034 [AG-1034]
   ✅ clean
   ✅ In sync with remote

📁 /path/to/agent-worktree/workspace/feat/#163 [feat/#163]
   ⚠  Uncommitted changes
   🔄 Out of sync with remote
```

### Remove a worktree after merging

```bash
# Clean up after PR is merged
./scripts/wt.sh remove AG-1034
```

Prompts for confirmation if there are uncommitted changes.

### Periodic cleanup

```bash
# Prune stale links + detect merged branches
./scripts/wt.sh cleanup
```

---

## 6. wt.sh command reference

| Command | Description |
|---------|-------------|
| `wt.sh list` | List all worktrees |
| `wt.sh create <branch> <base>` | Create worktree (checks out branch if it exists; creates new branch from `<base>` otherwise) |
| `wt.sh remove <branch>` | Remove worktree (prompts if uncommitted changes exist) |
| `wt.sh status` | Show clean/dirty and sync status for each worktree |
| `wt.sh cleanup` | Prune stale links and detect merged branches |
| `wt.sh repair` | Recover broken worktree links |
| `wt.sh lock <branch>` | Lock worktree to prevent accidental removal |
| `wt.sh unlock <branch>` | Unlock worktree |

---

## 7. Using with AI agents

One of the main purposes of this setup is **parallel AI agent execution**.

The workflow is:
1. Ask the agent to **create a worktree** for a branch
2. The agent creates it and tells you the path
3. You `cd` into the worktree and **start a new agent session there**
4. The new session auto-loads the project's agent config from that directory

```bash
# Step 1-2: ask the agent (from agent-worktree/ directory)
/worktree AG-1034                       → prepare AG-1034 worktree
/worktree feat/#163 from AG-1034        → create new worktree from AG-1034

# Step 3-4: start working in the worktree
cd workspace/AG-1034
<agent-cli>                             # e.g. claude, codex, gemini, aider, ...
```

**Why run the agent CLI directly inside the worktree?**
A subagent spawned from the parent session does **not** inherit the target project's config files (`CLAUDE.md`, `AGENTS.md`, skills, etc.). Running an agent CLI directly inside the worktree is the correct way to get full project context — the CLI reads config from the current working directory on startup.

Use the `/worktree` skill for management tasks:

```
/worktree list                          → list worktrees
/worktree status                        → check all worktrees
/worktree cleanup                       → clean up stale worktrees
```

---

## 8. Common mistakes

### ❌ Editing files inside the bare repo

```bash
# Wrong
cd agent-worktree/workspace/<project>.git
vim domain/clothes.go  # ← bare repo has no source files
```

Always work inside a worktree directory (`AG-1034/`, `feat/#163/`, etc.).

### ❌ Creating two worktrees for the same branch

One branch can only have one worktree at a time.

```bash
# This will fail
git -C <project>.git worktree add ./AG-1034-copy AG-1034
# fatal: 'AG-1034' is already checked out
```

### ❌ Deleting a worktree directory with rm

```bash
# Wrong
rm -rf agent-worktree/workspace/AG-1034/
```

This leaves a broken link inside the bare repo.
Always use `wt.sh remove` or `git worktree remove` instead.
If you already deleted it directly, run `wt.sh repair` to recover.

---

## 9. Summary

| Concept | One-line description |
|---------|----------------------|
| Bare repo | The git "brain" — contains history only, never edit directly |
| Worktree | Per-branch working directory — create when needed, delete when done |
| wt.sh | CLI tool for creating, removing, and inspecting worktrees |
| /worktree skill | Lets an agent manage worktrees via natural language |