# Claude Code hooks

Shared hooks that fire whenever Claude Code runs under `~/Projects/Wiser/`. Installed automatically by `setup.sh`.

## activity-log.sh

Writes an entry to Cloud Logging for every Claude tool call so §5.3 and §11 of the guardrails have a real audit trail to query during an incident.

### What it does

- Fires on `PreToolUse` and `PostToolUse` (every tool, matcher `.*`).
- Extracts the ticket id from the current git branch name (anything matching `WP23-\d+`). Branches without a ticket id are silently ignored, so non-ticket work does not pollute the log.
- Resolves the actor from `gh auth status` (cached once per session). Falls back to `$USER`.
- Redacts the shell command string before capping it at 500 characters. Full rule list in `../../schemas/activity_log.md`.
- Emits via `gcloud logging write` under the invoking developer's gcloud ADC. No service account key is distributed to laptops.

### Payload shape

Defined in `schemas/activity_log.md` at the repo root. The hook only lifts `file_path` and `command` from the tool input and drops every other input field; tool output is never logged.

### Non-blocking contract

The hook never fails a Claude tool call. Every failure path exits 0. On the first write failure in a session a one-line warning goes to stderr so a broken ADC or revoked grant does not stay silent; subsequent failures in the same session are silent.

### Local off-switch

Set `CLAUDE_ACTIVITY_LOG=off` in your shell to mute the hook on this machine. Useful when working offline or debugging the hook itself.

### Prerequisites

- `jq` (JSON parsing).
- `gcloud` (writer; needs an active ADC for `wiser-mainframe`).
- `perl` (multi-line redaction).
- `gh` (actor resolution, optional).

`setup.sh` warns at install time if `gcloud` or ADC is missing.

### Troubleshooting

- "wiser activity-log: write skipped" on stderr: the hook could not reach Cloud Logging. Check `gcloud auth list` and `gcloud config get-value project`; the project must be `wiser-mainframe`.
- No entries landing in Logs Explorer: confirm you are on a `WP23-NNN` branch; the hook skips when it cannot extract a ticket id from the branch name.
- To verify the shape of the hook input Claude Code sends you: `CLAUDE_ACTIVITY_LOG=off` in one shell, drop a temporary `cat > /tmp/sample.json` hook, trigger any tool call, inspect `/tmp/sample.json`.
