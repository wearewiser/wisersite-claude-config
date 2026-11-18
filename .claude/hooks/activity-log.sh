#!/usr/bin/env bash
# Claude agent activity log writer. Emits one JSON entry to Cloud Logging
# per tool call phase. Schema: schemas/activity_log.md.
#
# Usage: activity-log.sh <pre|post>
#
# Reads the Claude Code hook JSON on stdin. Never fails the user's tool
# call: every failure path exits 0, with one stderr warning on the first
# write failure per session.

set -u
PHASE="${1:-pre}"
SESSION_SENTINEL_DIR="${TMPDIR:-/tmp}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Local off-switch.
if [[ "${CLAUDE_ACTIVITY_LOG:-on}" == "off" ]]; then
  exit 0
fi

# Everything below is best-effort. Trap any error path back to exit 0.
log_fail() {
  local reason="$1"
  local session_id="${2:-unknown}"
  local sentinel="${SESSION_SENTINEL_DIR}/wiser-activity-log-warned-${session_id}"
  if [[ ! -f "$sentinel" ]]; then
    echo "wiser activity-log: write skipped ($reason). This warning fires once per session. See schemas/activity_log.md." >&2
    : > "$sentinel" 2>/dev/null || true
  fi
  exit 0
}

# Tooling check. Missing jq / gcloud is not fatal.
command -v jq >/dev/null 2>&1 || log_fail "jq not installed" "noinput"
command -v gcloud >/dev/null 2>&1 || log_fail "gcloud not installed" "noinput"

# Read hook input.
input="$(cat 2>/dev/null || true)"
if [[ -z "$input" ]]; then
  exit 0
fi

# Extract ticket from branch; skip silently when there's no WP23-NNN.
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
ticket_id="$(printf '%s' "$branch" | grep -oE 'WP23-[0-9]+' | head -1 || true)"
if [[ -z "$ticket_id" ]]; then
  exit 0
fi

# Core fields from the hook input. Only tool_name, session_id, and
# tool_use_id are lifted from the envelope. file_path / command come
# from tool_input and are redacted below. Nothing else from tool_input
# and nothing from tool_response is logged (see schemas/activity_log.md).
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
tool_use_id="$(printf '%s' "$input" | jq -r '.tool_use_id // empty' 2>/dev/null || true)"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
raw_command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

# Correlation id: tool_use_id is the authoritative shared id between a
# PreToolUse entry and its matching PostToolUse / PostToolUseFailure
# entry (schemas/activity_log.md). session_id is used only as a bucket
# for the first-failure-per-session stderr warning.
request_id="$tool_use_id"

# Actor: gh login if available, cached per session. Fall back to $USER.
actor_cache="${SESSION_SENTINEL_DIR}/wiser-gh-login"
if [[ ! -s "$actor_cache" ]]; then
  gh api user -q .login 2>/dev/null > "$actor_cache" || true
fi
actor="$(cat "$actor_cache" 2>/dev/null || true)"
if [[ -z "$actor" ]]; then
  actor="${USER:-unknown}"
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Redact the command string, then cap at 500 characters. The order is
# load-bearing: redact first so a token cut by truncation cannot slip
# through. Redaction rules live in lib/redact-command.sh and are pinned
# in schemas/activity_log.md.
command_redacted=""
if [[ -n "$raw_command" ]]; then
  command_redacted="$(printf '%s' "$raw_command" | "$HOOK_DIR/lib/redact-command.sh" 2>/dev/null || printf '%s' "$raw_command")"

  if (( ${#command_redacted} > 500 )); then
    command_redacted="${command_redacted:0:487}...[truncated]"
  fi
fi

# Status + severity. Claude Code fires PostToolUse only on success and
# PostToolUseFailure on any failure (hook-deny, tool-raised error,
# etc), so phase determines status directly without reading
# tool_response. Normalise the inbound phase label.
case "$PHASE" in
  pre)
    status="ok"
    severity="INFO"
    phase_out="pre"
    ;;
  post)
    status="ok"
    severity="INFO"
    phase_out="post"
    ;;
  post-failure)
    status="error"
    severity="WARNING"
    phase_out="post"
    ;;
  *)
    status="ok"
    severity="INFO"
    phase_out="$PHASE"
    ;;
esac

# Build the payload. Core fields first, then sidecar.
payload="$(jq -nc \
  --arg ticket_id "$ticket_id" \
  --arg action "tool_use" \
  --arg actor "$actor" \
  --arg timestamp "$timestamp" \
  --arg link "${session_id:-$request_id}" \
  --arg request_id "$request_id" \
  --arg tool_name "$tool_name" \
  --arg phase "$phase_out" \
  --arg status "$status" \
  --arg file_path "$file_path" \
  --arg command "$command_redacted" \
  '{
    ticket_id: $ticket_id,
    action: $action,
    actor: $actor,
    timestamp: $timestamp,
    link: $link,
    request_id: $request_id,
    tool_name: $tool_name,
    phase: $phase
  }
  + (if $status != "" then {status: $status} else {} end)
  + (if $file_path != "" then {file_path: $file_path} else {} end)
  + (if $command != "" then {command: $command} else {} end)' \
  2>/dev/null || true)"

if [[ -z "$payload" ]]; then
  log_fail "payload build failed" "$session_id"
fi

# Write to Cloud Logging. Non-blocking: any failure drops to log_fail
# which prints a one-time warning and exits 0.
if ! gcloud logging write devl-claude-agent-activity "$payload" \
  --payload-type=json \
  --severity="$severity" \
  --project=wiser-mainframe \
  --quiet 2>/dev/null; then
  log_fail "gcloud logging write failed" "$session_id"
fi

exit 0
