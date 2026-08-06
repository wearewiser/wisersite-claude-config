# wisersite-claude-config

Shared Claude Code configuration for all Wiser repos. Single source of truth for agents and the Claude workflow.

## What's in here

```
wisersite-claude-config/
├── agents/                          # shared Claude agents loaded by all repos
│   ├── branch-guardian.md
│   ├── dod-guardian.md
│   ├── dor-guardian.md
│   ├── secrets-guardian.md
│   └── ticket-planner.md
├── .github/workflows/
│   ├── claude-reusable.yml          # the actual Claude workflow logic
│   └── claude.yml                   # caller so this repo also gets Claude reviews
└── setup.sh                         # one-time local dev setup script
```

---

## How it works

### Locally

Claude Code discovers agents by walking up the directory tree from the current working directory. Because `~/Projects/Wiser/` has no `.git` file, any agents placed at `~/Projects/Wiser/.claude/agents/` are discovered for all repos inside that folder — without affecting other projects on your machine.

`setup.sh` creates `~/Projects/Wiser/.claude/agents/` as a **symlink** pointing directly at this repo's `agents/` folder. It also appends a `claude()` shell function to `~/.zshrc` that silently runs `git pull` on this repo every time you invoke `claude`. This means your agents are always up to date with no manual steps.

### CI

Each repo has a thin `claude.yml` that calls the reusable workflow in this repo (`claude-reusable.yml@main`). When a PR is opened, GitHub spins up a fresh container, the reusable workflow clones `wisersite-claude-config` and copies the agents in before Claude runs. The files exist only for the duration of that job — nothing is committed to individual repos. Any change made here is picked up by every repo on their next CI run.

---

## Developer setup (one-time)

1. Clone this repo into your Wiser projects folder:

```bash
git clone https://github.com/wearewiser/wisersite-claude-config.git ~/Projects/Wiser/wisersite-claude-config
```

2. If `~/Projects/Wiser/.claude/agents/` already exists as a real folder, delete it first:

```bash
rm -rf ~/Projects/Wiser/.claude/agents
```

3. Run the setup script:

```bash
cd ~/Projects/Wiser/wisersite-claude-config
./setup.sh
```

4. Reload your shell:

```bash
source ~/.zshrc
```

That's it. Agents are now scoped to Wiser and will update automatically every time you run `claude`.

---

## Adding Claude to a new repo

1. Add `ANTHROPIC_API_KEY` to the repo's secrets (GitHub → Settings → Secrets and variables → Actions)
2. Create `.github/workflows/claude.yml`:

```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]
  pull_request:
    types: [opened, synchronize, reopened]
  workflow_dispatch:
    inputs:
      prompt:
        description: "Task for Claude to complete"
        required: true
        type: string

jobs:
  claude:
    uses: wearewiser/wisersite-claude-config/.github/workflows/claude-reusable.yml@main
    secrets: inherit
```

3. Done — CI handles everything automatically from there.
