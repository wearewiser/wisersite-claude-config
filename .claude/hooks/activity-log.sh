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

# Defence in depth: any unexpected exit path (unbound variable under
# set -u, a trap from the shell, a signal) returns 0 so the hook can
# never fail a Claude tool call. Installed BEFORE any work the shell
# could crash on (HOOK_DIR computation under set -u, `cd` into a
# directory with surprising permissions, the scope-boundary case),
# so a failure in those lines still trips the EXIT handler and exits
# 0 instead of propagating up to Claude Code. log_fail below is the
# normal "write skipped" exit; this trap only catches the abnormal.
trap 'exit 0' EXIT

PHASE="${1:-pre}"
SESSION_SENTINEL_DIR="${TMPDIR:-/tmp}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Drain stdin up front, before any early-exit path. Claude Code pipes
# the hook input via stdin; a large payload (a Bash call carrying a big
# heredoc, a long Read window, etc) can exceed the pipe buffer. If we
# exit before reading, the writer's next write() blocks until the pipe
# drains and we are not here to drain it. The hook is now installed
# user-globally into ~/.claude/settings.json, so this would affect
# every tool call in every non-Wiser session on the machine. Always
# consume stdin into `input` and let later checks decide whether to
# exit.
input="$(cat 2>/dev/null || true)"

# Local off-switch.
if [[ "${CLAUDE_ACTIVITY_LOG:-on}" == "off" ]]; then
  exit 0
fi

# Wiser-scope boundary. The hook installs user-globally into
# ~/.claude/settings.json so it fires in every Claude Code session on
# the machine, not only sessions started in a Wiser repo. Branch-name
# extraction alone (WP23-NNN) is not enough to decide scope, because
# an unrelated project could coincidentally use the same ticket-naming
# convention and leak its commands and file paths into Wiser's log.
# Enforce the folder boundary explicitly: if cwd is not under
# ~/Projects/Wiser/, exit 0 silently. Stdin has already been drained
# above so the early exit cannot block Claude.
case "$PWD/" in
  "$HOME/Projects/Wiser/"*) ;;
  *) exit 0 ;;
esac

# Everything below is best-effort. log_fail prints one warning per
# session (keyed by session_id from the hook input) so a broken
# gcloud auth is not silent, but repeated calls do not spam stderr.
log_fail() {
  local reason="$1"
  # Argument is already sanitised by the caller (or empty); callers must
  # pass safe_session_id, not the raw session_id, so the sentinel path
  # cannot escape $TMPDIR via a '/' or '..' in the untrusted value.
  local session_id="${2:-}"
  if [[ -n "$session_id" ]]; then
    local sentinel="${SESSION_SENTINEL_DIR}/wiser-activity-log-warned-${session_id}"
    if [[ ! -f "$sentinel" ]]; then
      echo "wiser activity-log: write skipped ($reason). This warning fires once per session. See schemas/activity_log.md." >&2
      : > "$sentinel" 2>/dev/null || true
    fi
  else
    # No session_id yet; cannot key a per-session sentinel without one.
    # Warn on every invocation so the user notices; the tooling gap
    # that lands us here (missing jq, etc) is normally fixed quickly.
    echo "wiser activity-log: write skipped ($reason). See schemas/activity_log.md." >&2
  fi
  exit 0
}

# jq is needed to read session_id from the hook input; without it we
# cannot key the once-per-session sentinel, so warn without suppression.
if ! command -v jq >/dev/null 2>&1; then
  log_fail "jq not installed" ""
fi

# Hook input was drained into `input` at the top, before any early-exit
# path. Now that we are past the scope boundary and jq is confirmed,
# bail quietly if the pipe delivered nothing (Claude may invoke the hook
# with no payload during test runs).
if [[ -z "$input" ]]; then
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

# Sanitised copies for use in temp-file paths. Upstream Claude Code
# controls these values (session_id ~= UUID, tool_use_id = toolu_...)
# so in practice they only contain safe characters, but anything that
# is not alphanumeric / underscore / hyphen is collapsed to '_' as
# defence in depth: a stray '/' or '..' would otherwise land a
# sentinel outside $TMPDIR.
safe_session_id="${session_id//[^a-zA-Z0-9_-]/_}"
safe_tool_use_id="${tool_use_id//[^a-zA-Z0-9_-]/_}"

# gcloud check deferred to here so log_fail can key the once-per-session
# warning sentinel by the real session_id from the hook input.
if ! command -v gcloud >/dev/null 2>&1; then
  log_fail "gcloud not installed" "$safe_session_id"
fi

# Correlation id: tool_use_id is the authoritative shared id between a
# PreToolUse entry and its matching PostToolUse / PostToolUseFailure
# entry (schemas/activity_log.md). session_id is used only as a bucket
# for the first-failure-per-session stderr warning.
request_id="$tool_use_id"

# Ticket resolution, keyed by tool_use_id so the pre entry and its
# matching post entry stay attached to the same ticket even if the
# user switches branches between the two phases. Pre writes the cache;
# post reads and deletes it, falling back to the current branch if the
# cache was not captured (hook not wired at pre time, cache evicted).
if [[ -n "$tool_use_id" ]]; then
  ticket_cache="${SESSION_SENTINEL_DIR}/wiser-ticket-${safe_tool_use_id}"
else
  ticket_cache=""
fi

extract_ticket_from_branch() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  printf '%s' "$branch" | grep -oE 'WP23-[0-9]+' | head -1 || true
}

ticket_id=""
if [[ "$PHASE" == "pre" ]]; then
  ticket_id="$(extract_ticket_from_branch)"
  if [[ -z "$ticket_id" ]]; then
    exit 0
  fi
  if [[ -n "$ticket_cache" ]]; then
    # Destroy any pre-existing file at this path before writing. On a
    # shared /tmp a local attacker could pre-create the cache (umask
    # 077 only affects files we create, not files we truncate), then
    # rewrite its contents between our write and the post-phase read
    # to inject a crafted ticket_id into the audit log. `rm -f` plus
    # umask 077 guarantees the file we read back is one we authored.
    rm -f "$ticket_cache" 2>/dev/null || true
    ( umask 077 && printf '%s' "$ticket_id" > "$ticket_cache" ) 2>/dev/null || true
  fi
else
  # `-O` test rejects a cache file we do not own. Pairs with the
  # rm-before-write above: if an attacker raced in between the pre and
  # post phases, the file would no longer be owned by this user and
  # the read falls back to the live branch name.
  if [[ -n "$ticket_cache" && -s "$ticket_cache" && -O "$ticket_cache" ]]; then
    ticket_id="$(cat "$ticket_cache" 2>/dev/null || true)"
    rm -f "$ticket_cache" 2>/dev/null || true
  elif [[ -n "$ticket_cache" ]]; then
    # Attacker-created or not-owned-by-us: delete it so the next pre
    # starts from a clean slate, then fall back to the branch name.
    rm -f "$ticket_cache" 2>/dev/null || true
  fi
  if [[ -z "$ticket_id" ]]; then
    ticket_id="$(extract_ticket_from_branch)"
  fi
  if [[ -z "$ticket_id" ]]; then
    exit 0
  fi
fi

# Actor: gh login if available. Cached per session so switching accounts
# in another session does not leak the old login here, and so shared
# /tmp on multi-user systems does not cross-contaminate. When no
# session_id is present the cache is skipped entirely (fetched fresh
# each call) because a persistent nosession file would never invalidate
# and a stale account would attach to every future call.
if [[ -n "$session_id" ]]; then
  actor_cache="${SESSION_SENTINEL_DIR}/wiser-gh-login-${safe_session_id}"
  # Same TOCTOU defence as the ticket cache above: refuse to read a
  # file not owned by this user (would let a local attacker on shared
  # /tmp inject a crafted actor into the audit log), and `rm -f`
  # before writing so our umask-077 create cannot be aliased to an
  # attacker-controlled file.
  if [[ ! -s "$actor_cache" || ! -O "$actor_cache" ]]; then
    # Cold cache. `gh api user` can block for seconds if the GitHub
    # API is slow or unreachable, so synchronous call would break the
    # "hook adds ~20-50 ms" contract on the first tool call of a
    # fresh session. Write the $USER fallback into the cache first so
    # this call completes immediately with a usable actor, then
    # background the gh lookup to overwrite the cache for subsequent
    # calls in the same session. Trade-off: the first entry per
    # session attributes to $USER rather than the gh login; on
    # developer laptops those usually match anyway.
    rm -f "$actor_cache" 2>/dev/null || true
    ( umask 077 && printf '%s' "${USER:-unknown}" > "$actor_cache" ) 2>/dev/null || true
    # Redirect stdout/stderr inside the subshell BEFORE backgrounding
    # so the background does not inherit the hook's pipes. `disown`
    # alone unlinks the job from the shell's job table but does NOT
    # close the inherited file descriptors; without the redirect,
    # anything the background wrote could keep the hook's stdout /
    # stderr open until the background finished.
    (
      gh_login="$(gh api user -q .login 2>/dev/null || true)"
      if [[ -n "$gh_login" ]]; then
        ( umask 077 && printf '%s' "$gh_login" > "$actor_cache" ) 2>/dev/null || true
      fi
    ) >/dev/null 2>&1 &
    disown $! 2>/dev/null || true
  fi
  if [[ -O "$actor_cache" ]]; then
    actor="$(cat "$actor_cache" 2>/dev/null || true)"
  else
    actor=""
  fi
else
  # No session_id to key a per-session cache. Skip the gh call rather
  # than running it on every tool use (which would be synchronous and
  # unbounded in latency); fall through to the $USER fallback below.
  actor=""
fi
if [[ -z "$actor" ]]; then
  actor="${USER:-unknown}"
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Redact the command string, then cap at 500 characters. The order is
# load-bearing: redact first so a token cut by truncation cannot slip
# through. Redaction rules live in lib/redact-command.sh and are pinned
# in schemas/activity_log.md. On any redaction failure, log a marker
# instead of the raw command so a missing perl or broken lib cannot
# leak secrets.
command_redacted=""
if [[ -n "$raw_command" ]]; then
  # Check exit status explicitly: a perl crash mid-stream can produce
  # partially-redacted output before dying. Both a non-zero exit and
  # an empty result on non-empty input are treated as failure, so a
  # partial token cannot slip through the fallback.
  if ! command_redacted="$(printf '%s' "$raw_command" | "$HOOK_DIR/lib/redact-command.sh" 2>/dev/null)"; then
    command_redacted="[redaction-failed]"
  elif [[ -z "$command_redacted" ]]; then
    command_redacted="[redaction-failed]"
  fi

  if (( ${#command_redacted} > 500 )); then
    # ...[truncated] is 14 chars; 486 + 14 = 500 keeps the final
    # string inside the schema's 500-char cap. A naive 487 produced
    # 501.
    command_redacted="${command_redacted:0:486}...[truncated]"
  fi
fi

# Status + severity. Claude Code fires PostToolUse only on success and
# PostToolUseFailure on any failure (hook-deny, tool-raised error,
# etc), so phase determines status directly without reading
# tool_response. Normalise the inbound phase label.
case "$PHASE" in
  pre)
    status=""
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
    status=""
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
  log_fail "payload build failed" "$safe_session_id"
fi

# Write to Cloud Logging in the background. Each gcloud invocation
# cold-starts Python and does a network round-trip (approx 1-2 seconds).
# A session with hundreds of tool calls would otherwise block on
# minutes of cumulative hook time. Backgrounded with `&` plus `disown`
# so the hook returns to Claude Code immediately and the parent hook
# process is not waited on for the child's completion.
#
# Trade-off: a mid-session write failure can no longer be surfaced to
# stderr via log_fail because this parent process has already exited.
# setup.sh preflight catches the common cases (missing gcloud, no
# active account) at install time; a breakage that appears only
# mid-session (auth revoked, network partition) will show up as a gap
# in Logs Explorer rather than a stderr warning.
(
  gcloud logging write devl-claude-agent-activity "$payload" \
    --payload-type=json \
    --severity="$severity" \
    --project=wiser-mainframe \
    --quiet >/dev/null 2>&1
) &
# `2>/dev/null || true` so a race between `&` and `disown` (gcloud
# exits fast enough that its PID is already off the job table) does
# not print "no such job" to stderr. Matches the gh background above.
disown $! 2>/dev/null || true

exit 0
