# wisersite-claude-config

Shared Claude Code configuration for all Wiser repos. Single source of truth for agents, user-invoked skills, cross-repo ADRs, and the Claude workflow.

## What's in here

```
wisersite-claude-config/
├── PROJECT_KNOWLEDGE.md             # single-page project context loaded every session
├── agents/                          # shared Claude agents loaded by all repos
│   ├── branch-guardian.md
│   ├── design-fidelity-reviewer.md
│   ├── dod-guardian.md
│   ├── dor-guardian.md
│   ├── pr-reviewer.md
│   ├── secrets-guardian.md
│   ├── ticket-planner.md
│   └── local-only/                  # human-invoked agents, never copied to CI
│       └── codebase-reviewer.md
├── .claude/
│   ├── settings.example.json        # reference shape for the generated shared settings.json
│   ├── hooks/                       # shared Claude Code hooks loaded by all repos
│   │   ├── activity-log.sh
│   │   ├── lib/
│   │   │   └── redact-command.sh
│   │   ├── tests/
│   │   │   ├── redaction-vectors.jsonl
│   │   │   ├── run-redaction-tests.sh
│   │   │   └── probe-input.sh
│   │   └── README.md
│   └── skills/                      # user-invoked skills shared across repos
│       └── user-story-writer/
│           ├── SKILL.md
│           └── data-mapping/        # static copy of Wiser Data Brief tabs
├── docs/ADR/                        # Wiser-wide architecture decisions
│   ├── 0000-use-adrs.md
│   ├── 0001-llm-path-vertex-hosted-claude.md
│   └── 0002-gcp-cloud-functions-for-ingestion.md
├── guardrails/                      # Wiser-wide development guardrails
│   ├── DEVELOPMENT_GUARDRAILS.md
│   └── CHANGELOG.md
├── schemas/                         # pinned shared schemas (single source of truth)
│   └── activity_log.md
├── .github/workflows/
│   ├── claude-reusable.yml          # the actual Claude workflow logic
│   └── claude.yml                   # caller so this repo also gets Claude reviews
└── setup.sh                         # one-time local dev setup script
```

---

## How it works

### Locally

Claude Code discovers agents and skills by walking up the directory tree from the current working directory. Because `~/Projects/Wiser/` has no `.git` file, anything placed at `~/Projects/Wiser/.claude/agents/` or `~/Projects/Wiser/.claude/skills/` is discovered for all repos inside that folder, without affecting other projects on your machine.

`setup.sh` creates six symlinks under `~/Projects/Wiser/.claude/`:

- `agents/` -> this repo's `agents/` folder
- `skills/` -> this repo's `.claude/skills/` folder
- `adr/` -> this repo's `docs/ADR/` folder
- `guardrails/` -> this repo's `guardrails/` folder
- `hooks/` -> this repo's `.claude/hooks/` folder
- `PROJECT_KNOWLEDGE.md` -> this repo's `PROJECT_KNOWLEDGE.md` file (file-level symlink)

It also merges three `PreToolUse` / `PostToolUse` / `PostToolUseFailure` hook entries into `~/.claude/settings.json` (user-level) pointing at the hooks symlink with absolute paths; see the Activity-log hook section below for why.

It also appends a `claude()` shell function to `~/.zshrc` that silently runs `git pull` on this repo every time you invoke `claude`, so agents, skills, ADRs, guardrails, and project knowledge are always up to date with no manual steps.

Guardrails and project knowledge are a different shape from ADRs: they must load on **every** Claude session, not on demand. `setup.sh` therefore appends two import lines to `~/Projects/Wiser/CLAUDE.md` (creating that file if it does not exist):

- `@.claude/guardrails/DEVELOPMENT_GUARDRAILS.md`
- `@.claude/PROJECT_KNOWLEDGE.md`

Claude Code's hierarchical CLAUDE.md discovery then surfaces both in every session started under `~/Projects/Wiser/`.

Repos that want Claude to consult the shared ADRs should point at them from their `CLAUDE.md`, e.g. `Cross-repo ADRs: ~/Projects/Wiser/.claude/adr/`. ADRs are read on demand (not auto-loaded), so this only matters for repos where cross-cutting decisions are relevant.

### Activity-log hook

A shared `PreToolUse`, `PostToolUse`, and `PostToolUseFailure` hook (`.claude/hooks/activity-log.sh`) writes one entry per Claude tool call to Cloud Logging log `devl-claude-agent-activity` on `wiser-mainframe`, so guardrails §5.3 and §11 have a real audit trail to query during an incident. The hook extracts the ticket id from the current git branch (skipping silently on non-ticket branches), redacts secrets out of shell command strings, and never fails a tool call. Payload shape is pinned in `schemas/activity_log.md`; hook README is at `.claude/hooks/README.md`.

The hook fires in every Claude Code session on your machine, not only in Wiser repos. Claude Code loads `~/.claude/settings.json` on every session startup, and `setup.sh` merges the three hook entries into that file (preserving your existing `theme`, `permissions`, and anything else that already lives there). The hook itself is a no-op outside Wiser repos: it extracts a `WP23-NNN` ticket from the current git branch and exits 0 silently if there is no match, so sessions in non-Wiser projects pay only a `jq` and `git rev-parse` call per tool use. This user-level distribution is necessary because Claude Code does not walk the directory tree looking for `settings.json` the way it does for `CLAUDE.md`, so a shared file at `~/Projects/Wiser/.claude/settings.json` would never be discovered. The in-repo `.claude/settings.example.json` is a reference shape only; Claude Code does not load files with that name.

Writes run under the invoking developer's active `gcloud auth` account (the same account that `gcloud logging write` uses). No service account key is distributed to laptops. Prerequisites: `gcloud` on PATH and an active account via `gcloud auth login`. `setup.sh` warns at install time if either is missing. Local off-switch: `export CLAUDE_ACTIVITY_LOG=off`.

### CI

Each repo has a thin `claude.yml` that calls the reusable workflow in this repo (`claude-reusable.yml@main`). When a PR is opened, GitHub spins up a fresh container, the reusable workflow clones `wisersite-claude-config` and copies the top-level files of `agents/` into `.claude/agents/` and `docs/ADR/` into `.claude/adr/` before Claude runs. Skills are not copied to CI; they are user-invoked (via slash command or natural-language request), not something CI needs. The files exist only for the duration of that job; nothing is committed to individual repos. Any change made here is picked up by every repo on their next CI run.

Agents in `agents/local-only/` (currently `codebase-reviewer`) are deliberately not copied to CI. They are long-running and interactive (they can raise Jira tickets). Locally they are still discovered, because Claude Code scans `agents/` recursively.

---

## Developer setup (one-time)

1. Clone this repo into your Wiser projects folder:

```bash
git clone https://github.com/wearewiser/wisersite-claude-config.git ~/Projects/Wiser/wisersite-claude-config
```

2. If `~/Projects/Wiser/.claude/agents/`, `~/Projects/Wiser/.claude/skills/`, or `~/Projects/Wiser/.claude/adr/` already exists as a real folder, delete it first:

```bash
rm -rf ~/Projects/Wiser/.claude/agents ~/Projects/Wiser/.claude/skills ~/Projects/Wiser/.claude/adr
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

That's it. Agents, skills, ADRs, guardrails, and project knowledge are now scoped to Wiser and will update automatically every time you run `claude`.

**First-run import approval.** The first Claude Code session you start in a Wiser repo after setup may prompt you to approve importing `~/Projects/Wiser/CLAUDE.md` (the file setup.sh wrote). The imports resolve to symlinks pointing outside the current repo, and Claude Code treats those as external imports. Approve them; silently declining means the guardrails or project-knowledge doc do not load for that session and the shared context is bypassed. The prompt is per-user, per-project, and only appears once.

### Upgrading an existing install

The `claude()` shell wrapper only runs `git pull` on this repo on every launch; it does not re-run `setup.sh`. If a change here introduces new wiring (a new symlink target, a new `@import` line in `~/Projects/Wiser/CLAUDE.md`, a new shared file to distribute), existing devs must re-run setup once to pick it up. Content updates to existing files flow automatically.

```bash
cd ~/Projects/Wiser/wisersite-claude-config && ./setup.sh && source ~/.zshrc
```

Re-running is idempotent: existing symlinks are refreshed, existing import lines are left as-is.

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

---

## Using shared skills

Skills in `.claude/skills/` are **user-invoked**, not auto-loaded. In any Claude Code session under `~/Projects/Wiser/`, invoke a skill by its slash command (e.g. `/user-story-writer`) or by natural-language request ("use the user-story-writer skill to...").

### user-story-writer

Drafts, amends, splits, or tidies up Wiser user stories from mixed source material: Claude Design canvases, Jira tickets, screenshots, meeting notes, transcripts, and requirement docs. Produces DoR-aligned Given/When/Then acceptance criteria with source traceability. Writes to Jira only on explicit user approval. See `.claude/skills/user-story-writer/SKILL.md` for full behaviour.

**Per-user prerequisites:**

- Atlassian MCP configured and authenticated. Part of the standard Wiser Claude Code rig; re-authenticate periodically via `/mcp` when the OAuth token expires.
- `claude_design` MCP, only required when a Claude Design canvas is in your source material. Install once per user:

```bash
claude mcp add --transport http claude_design https://api.anthropic.com/v1/design/mcp
```

Then run `/mcp` inside a Claude Code session, select `claude_design`, and complete the OAuth flow. Skip this if you never feed canvases to the skill.

---

## Adding a new skill

New skills land in `.claude/skills/<skill-name>/SKILL.md`. Follow Claude Code's SKILL.md conventions: name and description in frontmatter, clear invocation criteria, one directory per skill. Once merged to `main`, every dev's next `claude` launch picks it up automatically via the shell wrapper `git pull`. Skills are not distributed to CI.

---

## Adding a new cross-repo ADR

New Wiser-wide architecture decisions land in `docs/ADR/`. Follow the existing numbering (increment from the last file) and the format defined in `0000-use-adrs.md`.

Once merged to `main`, every dev's next `claude` launch picks it up automatically via the shell wrapper `git pull`. Every downstream CI run picks it up on its next PR trigger, no consumer-side change required.

Repo-scoped decisions (internal to a single service, e.g. response-shape contracts, module boundaries within one repo) stay in that service's own `docs/ADR/`, not here. See `0000-use-adrs.md` for the scope boundary.

---

## Updating project knowledge

`PROJECT_KNOWLEDGE.md` is the single-page project overview loaded into every Claude session. Keep it short; it is a tax on every conversation. The file itself documents its own update rules — read the "Updating this document" section at the bottom before editing. Rough budget: ~300 lines / ~3k tokens.

Shape of a good change: a one-line entry under an existing section, or a new row in the "If X breaks, look here" table. Shape of a bad change: pasting in a decision log from a ticket. Decisions that shape future work belong in an ADR and are referenced from here.
