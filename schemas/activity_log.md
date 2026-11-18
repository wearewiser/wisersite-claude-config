# Claude agent activity log schema

**Version:** v1
**Status:** Active (devl)
**Owner:** John Zissimou
**Review:** schema changes require sign-off from the ticket assignee plus Lachlan Shaw-Stewart (content and governance); writer-architecture changes from Ian Moss.

## Purpose

Defines the payload shape, action enum, severity mapping, and command-string redaction rules for every entry written to the Claude agent activity log in Cloud Logging. Writers in any language or runtime must cite this file. Covers:

- Local developer sessions, emitted by the `PreToolUse` / `PostToolUse` shell hooks under `wisersite-claude-config/.claude/`.
- Future writers, including any Python writer using `wiser_shared.logs` (e.g. a Cloud Run function emitting activity events).

Field names, enum values, severity mapping, and the redaction regex list are pinned here so the shell hook and any future Python writer cannot drift. A single Logs Explorer query returns consistent results across sources.

## Log destination

| Env | Log name | Project | Writer SA (CI / Cloud Run) | Writer identity (local) |
| --- | --- | --- | --- | --- |
| devl | `devl-claude-agent-activity` | `wiser-mainframe` | `devops@wiser-mainframe.iam.gserviceaccount.com` | invoking developer's active gcloud auth account |
| prod | `prod-claude-agent-activity` (follow-up ticket) | `wiser-mainframe` | TBD | TBD |

Local writes emit under the invoking developer's active gcloud auth account; the `devops@` service account is reserved for CI or Cloud Run paths if and when they are wired.

## Payload shape

Entries are JSON. Core fields are required for every entry; sidecar fields are optional and populated when relevant.

### Core fields

| Field | Type | Required | Shape | Notes |
| --- | --- | --- | --- | --- |
| `ticket_id` | string | yes | `WP23-NNN` | Session-scoped; extracted from the current git branch name or passed in by the caller. |
| `action` | enum string | yes | one of the values in the closed enum below | Add-only migration. |
| `actor` | string | yes | GitHub-login style | Local = user's gh login; CI Claude = `claude-code[bot]`; Cloud Run job = function-SA-derived name (e.g. `cg-devl-ai-system`). No email, no display name, no personal data. |
| `timestamp` | string | yes | RFC3339 in UTC | e.g. `2026-11-18T12:34:56Z`. Python: `datetime.now(timezone.utc).isoformat()`. Shell: `date -u +%FT%TZ`. |
| `link` | string | yes | URL or opaque ID | PR URL / commit SHA / CircleCI job URL / deployment ID. For `tool_use` entries, the Claude session identifier. |

### Sidecar fields (optional)

| Field | Type | When populated | Notes |
| --- | --- | --- | --- |
| `tenant_id` | string | session is tenant-scoped | null for guardrails or infra work. Matches existing `wiser_shared.logs child()` tagging. |
| `request_id` | string | correlating across writers | For joining against other `wiser_shared.logs` emissions. |
| `tool_name` | string | `action = tool_use` | Which tool Claude invoked (e.g. `Bash`, `Edit`, `Read`, `Write`). |
| `phase` | enum string | `action = tool_use` | `pre` or `post`. Distinguishes the two entries emitted per tool call. |
| `status` | enum string | `action = tool_use`, `phase = post` | `ok` on `PostToolUse`, `error` on `PostToolUseFailure`. A blocked call emits no post entry at all; the gap (a pre with no matching post) is the signal. |
| `file_path` | string | `action = tool_use`, tool reads / edits / writes a file | The target path from `tool_input.file_path`. This is the only field name on current Claude Code (verified against the upstream hooks reference); legacy `.path` is not read. Before / after text is never logged. |
| `command` | string | `action = tool_use`, `tool_name = Bash` | Shell command string from `tool_input.command`, after the redaction pass below. Capped at 500 characters post-redaction. |

The hook lifts only `file_path` and `command` from `tool_input` and drops every other `tool_input` field. Tool output (stdout, stderr, exit code, returned content) is never logged.

## Closed `action` enum (v1)

Add-only. New values require a schema version bump.

| Value | Wired? | Source |
| --- | --- | --- |
| `tool_use` | yes, in WP23-546 | Local hook writer |
| `pr_opened` | reserved | Follow-up: GitHub webhook or cron mirror |
| `pr_reviewed` | reserved | Follow-up: GitHub webhook or cron mirror |
| `pr_merged` | reserved | Follow-up: GitHub webhook or cron mirror |
| `deployment_approved` | reserved | Follow-up: CircleCI mirror |

CI-side `tool_use` capture is tracked on WP23-639 (Sprint 10).

## Severity mapping

Writers must stamp Cloud Logging severity consistently with the table below so alert policies can key off `severity` without knowing the writer.

| Entry | Severity | Status field | Rationale |
| --- | --- | --- | --- |
| `tool_use`, `phase = pre` (`PreToolUse`) | `INFO` | omitted | Marks that a tool call started; status is populated only when the call completes. |
| `tool_use`, `phase = post`, `status = ok` (`PostToolUse`) | `INFO` | `ok` | Routine; no operator action needed. |
| `tool_use`, `phase = post`, `status = error` (`PostToolUseFailure`) | `WARNING` | `error` | The tool call failed; the user's session continues. No pager. |
| `pr_opened` / `pr_reviewed` / `pr_merged` / `deployment_approved` | `INFO` | omitted | Routine audit trail. |
| Write failure logged by the hook itself (first failure per session, stderr only) | `WARNING` | n/a | Not written to Cloud Logging; stderr only. Prevents silent failure. |

## Command-string redaction

Shell commands can carry secrets as values, flags, headers, or URL credentials. The hook runs this redaction pass **before** applying the 500-character cap, so a token split by truncation cannot slip through unredacted. Rules below are declarative; the `activity-log.sh` hook implements them and ships with a test-vector set under `.claude/hooks/tests/`.

Redaction is best-effort and not a security guarantee; guardrail §6 still applies (secrets must not be typed into shell prompts).

### Patterns to redact

1. **`KEY=value` env-style assignments** where `KEY` contains (case-insensitive) any of: `token`, `secret`, `key`, `password`, `pass`, `auth`, `credential`, `api_key`. Match the keyword anywhere in the name so `GITHUB_TOKEN`, `AWS_SECRET_ACCESS_KEY`, `DATABASE_URL` style names are covered. Value replaced with `[redacted]`. Quoted values (single or double, with spaces) also redacted.
2. **URL credentials.** `scheme://user:pass@host` forms including `postgres://`, `mysql://`, `https://user:token@github.com`, and `DATABASE_URL=postgres://...` style. Redact the `user:pass` portion to `[redacted]`.
3. **Flag forms.** `--password <value>`, `--token=<value>`, `--secret <value>`, `-p <value>` where the context is clearly auth, `curl -u user:pass`. Value replaced with `[redacted]`.
4. **JSON forms embedded in shell.** `-d '{"api_key":"..."}'`, `--data '{"token":"..."}'` and equivalents. Value within the JSON string replaced with `[redacted]`.
5. **HTTP headers.** `-H 'Authorization: ...'`, `--header 'Authorization: ...'`, and the same shapes for `X-API-Key`, `x-goog-api-key`, `Cookie`, `Private-Token`. Header value replaced with `[redacted]`.
6. **Known-prefix tokens.** Replace the suffix after the prefix with `[redacted]` for: `ghp_`, `ghs_`, `github_pat_`, `gho_`, `xoxb-`, `xoxp-`, `AKIA`, `AIza`, `ya29.`, `GOCSPX-`, `eyJ` (JWT), and `Bearer `. The `sk-` prefix (OpenAI / Anthropic API keys) requires a word boundary plus a minimum suffix length so `task-`, `disk-`, and similar substrings are not false-positived.
7. **Private-key blocks.** Any `-----BEGIN [A-Z ]+PRIVATE KEY-----` through `-----END [A-Z ]+PRIVATE KEY-----` run. Whole block replaced with `[redacted-private-key]`. Multi-line.
8. **Heredocs.** `cat > .env <<EOF`, `cat > secrets.yaml <<'SECRETS'`, and similar shapes may embed file contents in the command string. The regex pass runs multi-line so heredoc bodies are subject to every rule above.

### Length cap

After the redaction pass, the resulting command string is truncated to 500 characters. Truncation appends `...[truncated]`. Order is load-bearing: redact first, then cap.

### Test vectors

Every change to the redaction rules above must ship with an updated test-vector file (`.claude/hooks/tests/redaction-vectors.jsonl`) and a sign-off from Lachie. Each vector pairs an input command with its expected redacted output.

## Write semantics

- **Best-effort, non-blocking.** A write failure must never fail the user's tool call or block the Claude session. The hook catches every failure path and exits 0.
- **First-failure visibility.** On the first write failure within a session, the hook emits a one-line warning to stderr so a broken gcloud auth or revoked grant does not stay silent. Subsequent failures within the same session stay silent.
- **No retry.** Matches the `wiser_shared.logs` convention (stdlib stdout, no buffering, no retry).

## Correlation

Two entries are emitted per tool call:

- A `PreToolUse` entry (`phase = pre`, `status` omitted) when the tool call starts.
- Either a `PostToolUse` entry on success (`phase = post`, `status = ok`) or a `PostToolUseFailure` entry on failure (`phase = post`, `status = error`). A successful call never emits both.

The two entries share `request_id`, which is sourced directly from the Claude Code hook input's `tool_use_id` field (verified authoritative on the late-2026 upstream schema, https://code.claude.com/docs/en/hooks.md). A `PreToolUse` with no matching `post` entry means the call was blocked or the session terminated between pre and post; the gap itself is the signal. Investigators query by `jsonPayload.request_id` to pair entries.

`session_id` is still carried on each entry for coarse grouping across every tool call in a single session, but is not used as a correlation key.

## Change process

- Every change to this file is a PR against `develop` on `wisersite-claude-config`.
- Field additions and new `action` enum values are add-only; no renames, no type changes, no removals.
- A breaking change requires a schema version bump (currently v1) and a documented migration path.
- Reviewers: ticket assignee plus Lachlan Shaw-Stewart (schema / content), Ian Moss (writer architecture) when the writer surface is affected.

## Query

Incident lookup query for everything Claude did on a ticket:

```
logName="projects/wiser-mainframe/logs/devl-claude-agent-activity"
AND jsonPayload.ticket_id="WP23-NNN"
```

Scope by actor, action, or tool name using additional `jsonPayload.*` filters.
