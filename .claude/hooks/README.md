# Claude Code hooks

Shared hooks that fire whenever Claude Code runs under `~/Projects/Wiser/`. Installed automatically by `setup.sh`.

## activity-log.sh

Writes an entry to Cloud Logging for every Claude tool call so §5.3 and §11 of the guardrails have a real audit trail to query during an incident.

### What it does

- Fires on `PreToolUse`, `PostToolUse`, and `PostToolUseFailure` (every tool, matcher `.*`).
- Extracts the ticket id from the current git branch name (anything matching `WP23-\d+`). The ticket is cached at pre keyed by `tool_use_id` and re-used at post, so branch switches between the two phases do not split the pair across tickets. Branches without a ticket id are silently ignored.
- Resolves the actor from `gh auth status`, cached per `session_id` (not globally). Falls back to `$USER`.
- Redacts the shell command string before capping it at 500 characters. Full rule list in `../../schemas/activity_log.md`.
- Emits via `gcloud logging write` under the invoking developer's **active `gcloud auth` account** (same store `gcloud logging write` reads from). No service account key is distributed to laptops.

### Payload shape

Defined in `schemas/activity_log.md` at the repo root. The hook only lifts `file_path` and `command` from the tool input and drops every other input field; tool output is never logged.

### Non-blocking contract

The hook never fails a Claude tool call. The `gcloud logging write` call is backgrounded with `& disown` so the hook returns to Claude Code without waiting for the network round-trip; per-tool-call latency is the hook script's own work (about 20-50 ms), not gcloud's cold start (1-2 s). Every synchronous failure path exits 0. Mid-session write failures cannot be surfaced to stderr (the parent hook has already exited); setup.sh preflight catches the common breakages at install time, and mid-session failures show up as a gap in Logs Explorer.

### Local off-switch

Set `CLAUDE_ACTIVITY_LOG=off` in your shell to mute the hook on this machine. Useful when working offline or debugging the hook itself.

### Prerequisites

- `jq` (JSON parsing).
- `gcloud` (writer; needs an active account via `gcloud auth login`, which is what `gcloud logging write` uses).
- `perl` (multi-line redaction).
- `gh` (actor resolution, optional).

`setup.sh` warns at install time if `gcloud` is missing or no active account is configured.

### Testing the redaction rules

Redaction regexes live in `lib/redact-command.sh` and are pinned by a vector suite at `tests/redaction-vectors.jsonl`. Each vector pairs an input command with its expected redacted output. Run:

```bash
./tests/run-redaction-tests.sh
```

Any rule change must land with an updated vector set and a reviewer sign-off from Lachlan Shaw-Stewart. To regenerate expected outputs after an approved rule change, use `./tests/run-redaction-tests.sh --generate` and paste the resulting JSONL back into the vectors file after eyeballing it.

### Troubleshooting

- "wiser activity-log: write skipped" on stderr: the hook could not reach Cloud Logging. Check `gcloud auth list` and `gcloud config get-value project`; the project must be `wiser-mainframe`.
- No entries landing in Logs Explorer: confirm you are on a `WP23-NNN` branch; the hook skips when it cannot extract a ticket id from the branch name.
- To verify the shape of the hook input Claude Code sends you: `CLAUDE_ACTIVITY_LOG=off` in one shell, drop a temporary `cat > /tmp/sample.json` hook, trigger any tool call, inspect `/tmp/sample.json`.
