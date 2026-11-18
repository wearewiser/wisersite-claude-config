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
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
raw_command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

# Correlation id: prefer tool_use_id, fall back to session_id, then a
# per-call uuid as last resort. Documented in schemas/activity_log.md.
if [[ -n "$tool_use_id" ]]; then
  request_id="$tool_use_id"
elif [[ -n "$session_id" ]]; then
  request_id="$session_id"
else
  request_id="$(uuidgen 2>/dev/null || date -u +%s%N)"
fi

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

# Redact the command string. Rules are declarative in
# schemas/activity_log.md; this is the implementation. Multi-line (-0777
# slurp) so heredocs are covered. Redaction runs BEFORE the length cap
# so a token cut by truncation cannot slip through.
command_redacted=""
if [[ -n "$raw_command" ]]; then
  command_redacted="$(printf '%s' "$raw_command" | perl -0777 -pe '
    # Private-key blocks (multi-line).
    s/-----BEGIN [A-Z ]+PRIVATE KEY-----.*?-----END [A-Z ]+PRIVATE KEY-----/[redacted-private-key]/gs;

    # Known-prefix tokens. sk- requires word boundary + min length.
    s/\bsk-[A-Za-z0-9_\-]{20,}/sk-[redacted]/g;
    s/\bghp_[A-Za-z0-9_]+/ghp_[redacted]/g;
    s/\bghs_[A-Za-z0-9_]+/ghs_[redacted]/g;
    s/\bgho_[A-Za-z0-9_]+/gho_[redacted]/g;
    s/\bgithub_pat_[A-Za-z0-9_]+/github_pat_[redacted]/g;
    s/\bxox[bp]-[A-Za-z0-9\-]+/xox[redacted]/g;
    s/\bAKIA[A-Z0-9]{16}/AKIA[redacted]/g;
    s/\bAIza[A-Za-z0-9_\-]+/AIza[redacted]/g;
    s/\bya29\.[A-Za-z0-9_\-]+/ya29.[redacted]/g;
    s/\bGOCSPX-[A-Za-z0-9_\-]+/GOCSPX-[redacted]/g;
    s/\beyJ[A-Za-z0-9_\-\.]{20,}/eyJ[redacted]/g;
    s/\bBearer\s+[A-Za-z0-9_\-\.=]+/Bearer [redacted]/gi;

    # URL credentials: scheme://user:pass@host.
    s/([a-z][a-z0-9+.\-]*:\/\/)[^\s:@\/]+:[^\s@\/]+@/$1[redacted]@/gi;

    # Headers: Authorization, X-API-Key, x-goog-api-key, Cookie, Private-Token.
    # Covers -H, --header, and raw header forms.
    s/((?:-H|--header)\s+["\x27]?)(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)[^"\x27\n]+/$1$2$3[redacted]/gi;
    s/\b(Authorization|X-API-Key|x-goog-api-key|Cookie|Private-Token)(\s*:\s*)[^\s"\x27,;]+/$1$2[redacted]/gi;

    # curl -u user:pass form.
    s/(-u\s+)[^\s]+/$1[redacted]/g;

    # Flag forms: --password, --token, --secret, --api-key (with = or space).
    s/(--(?:password|token|secret|api[\-_]?key|auth|credential)[=\s])["\x27]?[^\s"\x27]+["\x27]?/$1[redacted]/gi;

    # JSON embedded in shell: "key":"value" where key contains a keyword.
    s/("(?:[A-Za-z_\-]*(?:token|secret|key|password|pass|auth|credential|api[_\-]?key)[A-Za-z_\-]*)"\s*:\s*)"[^"]+"/$1"[redacted]"/gi;

    # KEY=value env assignments where KEY contains a keyword anywhere.
    # Matches quoted and unquoted values, keyword anywhere in the name
    # (so GITHUB_TOKEN, AWS_SECRET_ACCESS_KEY, DATABASE_URL match).
    s/(\b[A-Za-z_][A-Za-z0-9_]*(?:TOKEN|SECRET|KEY|PASSWORD|PASS|AUTH|CREDENTIAL|API_KEY|DATABASE_URL)[A-Za-z0-9_]*\s*=\s*)(["\x27])(?:(?!\2).)*\2/$1$2[redacted]$2/gi;
    s/(\b[A-Za-z_][A-Za-z0-9_]*(?:TOKEN|SECRET|KEY|PASSWORD|PASS|AUTH|CREDENTIAL|API_KEY|DATABASE_URL)[A-Za-z0-9_]*\s*=\s*)(?!["\x27])[^\s;&|]+/$1[redacted]/gi;
  ' 2>/dev/null || printf '%s' "$raw_command")"

  # Length cap: 500 chars post-redaction, truncate marker appended.
  if (( ${#command_redacted} > 500 )); then
    command_redacted="${command_redacted:0:487}...[truncated]"
  fi
fi

# Compute status + severity. Pre entries are always INFO/ok. Post
# entries read tool_response for an exit_code or error marker.
status="ok"
severity="INFO"
if [[ "$PHASE" == "post" ]]; then
  exit_code="$(printf '%s' "$input" | jq -r '.tool_response.exit_code // 0' 2>/dev/null || echo 0)"
  blocked="$(printf '%s' "$input" | jq -r '.tool_response.blocked // empty' 2>/dev/null || true)"
  error_marker="$(printf '%s' "$input" | jq -r '.tool_response.error // empty' 2>/dev/null || true)"
  if [[ -n "$blocked" ]]; then
    status="blocked"
    severity="WARNING"
  elif [[ "$exit_code" != "0" && -n "$exit_code" ]] || [[ -n "$error_marker" ]]; then
    status="error"
    severity="WARNING"
  fi
fi

# Build the payload. Core fields first, then sidecar.
payload="$(jq -nc \
  --arg ticket_id "$ticket_id" \
  --arg action "tool_use" \
  --arg actor "$actor" \
  --arg timestamp "$timestamp" \
  --arg link "${session_id:-$request_id}" \
  --arg request_id "$request_id" \
  --arg tool_name "$tool_name" \
  --arg phase "$PHASE" \
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
