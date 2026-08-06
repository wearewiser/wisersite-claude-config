# wisersite-claude-config

Shared Claude Code configuration for all Wiser repos. Single source of truth for agents, hooks, and settings.

## What's in here

- `agents/` — shared Claude agents (branch-guardian, dod-guardian, dor-guardian, ticket-planner, secrets-guardian)

## Local dev setup (one-time)

Clone this repo into your Wiser projects folder:

```bash
git clone https://github.com/wearewiser/wisersite-claude-config.git ~/Projects/Wiser/wisersite-claude-config
```

Run the setup script:

```bash
cd ~/Projects/Wiser/wisersite-claude-config
chmod +x setup.sh
./setup.sh
source ~/.zshrc
```

This will:
1. Symlink `~/Projects/Wiser/.claude/agents/` to this repo's `agents/` folder
2. Append a `claude()` shell function to `~/.zshrc` that silently pulls the latest agents every time you run `claude`

Agents are scoped to `~/Projects/Wiser/` — they will not affect other projects on your machine.

## Keeping agents up to date

Nothing to do. Every time you run `claude`, the shell function pulls the latest changes automatically.

## CI

Each repo's `claude.yml` clones this repo at runtime and copies agents in before Claude runs. Nothing is committed to individual repos.
