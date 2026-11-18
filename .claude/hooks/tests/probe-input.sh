#!/usr/bin/env bash
# Development probe for the Claude Code PreToolUse / PostToolUse hook
# input shape. Dumps each incoming stdin JSON payload to a timestamped
# file under /tmp so we can inspect what Claude Code actually sends
# (session_id, tool_use_id, tool_input, tool_response, etc).
#
# Usage (does not touch the committed settings.json):
#   1. Create .claude/settings.local.json in this repo with:
#        {
#          "hooks": {
#            "PreToolUse": [
#              {
#                "matcher": ".*",
#                "hooks": [
#                  { "type": "command",
#                    "command": ".claude/hooks/tests/probe-input.sh pre" }
#                ]
#              }
#            ],
#            "PostToolUse": [
#              {
#                "matcher": ".*",
#                "hooks": [
#                  { "type": "command",
#                    "command": ".claude/hooks/tests/probe-input.sh post" }
#                ]
#              }
#            ]
#          }
#        }
#      settings.local.json merges with settings.json, so the probe runs
#      alongside activity-log.sh rather than replacing it.
#   2. Start a fresh Claude Code session inside this repo and run a
#      couple of tool calls (any Bash, Read, Edit).
#   3. Inspect the dumps:
#        ls /tmp/claude-hook-probe-*.json | head
#        jq . /tmp/claude-hook-probe-pre-*.json | head -40
#        jq . /tmp/claude-hook-probe-post-*.json | head -40
#   4. Delete .claude/settings.local.json and rm /tmp/claude-hook-probe-*.json.
#
# What to look for:
#   - .session_id          present? stable across the whole session?
#   - .tool_use_id         present? paired between a pre entry and its
#                          matching post entry?
#   - .tool_input.command  present for Bash calls?
#   - .tool_input.file_path or .path present for Read/Edit/Write?
#   - .tool_response       shape on post entries (exit_code, stdout,
#                          stderr, error, blocked flags)?
#
# If .tool_use_id is reliably present, lib activity-log.sh can drop
# the session_id and uuidgen fallbacks on the correlation chain.
#
# The probe exits 0 so it never fails a tool call.

set -u
PHASE="${1:-pre}"
OUT_DIR="${TMPDIR:-/tmp}"
STAMP="$(date -u +%Y%m%dT%H%M%S)-${RANDOM}"
OUT_FILE="${OUT_DIR}/claude-hook-probe-${PHASE}-${STAMP}.json"

cat > "$OUT_FILE" 2>/dev/null || true
exit 0
