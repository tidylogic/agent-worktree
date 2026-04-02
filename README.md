# agent-worktree

> 🤖 AI translated This document.
> The original is written in Korean: [README-KO.md](./README-KO.md)

A template for running multiple Claude agents in parallel — each on a separate branch, with zero conflict.

```
agent-worktree/
├── scripts/wt.sh        ← worktree manager script
├── .claude/skills/      ← Claude /worktree skill
└── workspace/           ← gitignored: your project lives here
    ├── <project>.git/   ← bare repo
    └── <branch-name>/   ← per-branch working directory (worktree)
```

## Quick Start

```bash
# 1. Clone this template
git clone https://github.com/tidylogic/agent-worktree
cd agent-worktree

# 2. Make the script executable
chmod +x scripts/wt.sh

# 3. Add your project as a bare repo inside workspace/
git clone --bare <your-repo-url> workspace/<project>.git

# 4. Create a worktree and start working
./scripts/wt.sh create <branch-name> <base-branch>
cd workspace/<branch-name>
```

## wt.sh Commands

| Command | Description |
|---------|-------------|
| `wt.sh list` | List all worktrees |
| `wt.sh create <branch> <base>` | Create worktree (creates branch from `<base>` if it doesn't exist) |
| `wt.sh remove <branch>` | Remove worktree (prompts if there are uncommitted changes) |
| `wt.sh status` | Show clean/dirty and sync status for all worktrees |
| `wt.sh cleanup` | Prune stale links and detect merged branches |
| `wt.sh repair` | Recover broken worktree links |

## Language

Output language is configured in `settings.json`:

```json
{ "lang": "en" }
```

Supported values: `en`, `ko`

## Using with an AI agent

Run your agent CLI from this directory and the `/worktree` skill loads automatically.
Ask the agent to create a worktree — then `cd` into it and start a new agent session there.
The new session auto-loads the project's agent config (`CLAUDE.md`, `AGENTS.md`, `.claude/skills/`, etc.).

```
/worktree feat/#163 from AG-1034         → create worktree
/worktree status                         → check all worktrees
```

Once the worktree is ready:

```bash
cd workspace/<branch-name>
<agent-cli>                              # e.g. claude, codex, gemini, aider, ...
```

See [ONBOARDING.md](./ONBOARDING.md) for a full walkthrough.
