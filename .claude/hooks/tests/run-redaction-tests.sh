#!/usr/bin/env bash
# Runs redaction-vectors.jsonl through lib/redact-command.sh and
# compares each actual output to its expected value. One file per
# PR review from Lachie, per schemas/activity_log.md.
#
# Usage:
#   ./run-redaction-tests.sh                 # default: test mode
#   ./run-redaction-tests.sh --generate      # emit ACTUAL outputs
#     (use after approving a rule change; paste the output back
#      into redaction-vectors.jsonl so the suite pins the new
#      behaviour.)

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/../lib/redact-command.sh"
VECTORS="$HERE/redaction-vectors.jsonl"

if [[ "${1:-}" == "--generate" ]]; then
  MODE="generate"
else
  MODE="test"
fi

if [[ ! -x "$LIB" ]]; then
  echo "error: redaction lib not found or not executable at $LIB" >&2
  exit 2
fi

if [[ ! -f "$VECTORS" ]]; then
  echo "error: vectors file not found at $VECTORS" >&2
  exit 2
fi

# Fail fast if jq is missing. Without jq the per-vector `name`, `input`,
# and `expected` extractions silently produce empty strings, the lib is
# fed empty input, actual == expected (both empty), and every vector
# counts as passing. The suite would exit 0 while testing nothing - a
# false green that would let a real redaction regression ship. Lachie
# signs off on each rule change against this suite, so false passes are
# load-bearing to skip.
if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to parse the vectors file." >&2
  echo "       install jq (brew install jq / apt install jq) and re-run." >&2
  exit 2
fi

PASS=0
FAIL=0
FAILURES=""

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name="$(printf '%s' "$line" | jq -r '.name')"
  input="$(printf '%s' "$line" | jq -r '.input')"
  expected="$(printf '%s' "$line" | jq -r '.expected')"
  actual="$(printf '%s' "$input" | "$LIB")"

  if [[ "$MODE" == "generate" ]]; then
    # Emit a JSONL line with the ACTUAL output as the expected value.
    # Reviewer eyeballs each line to confirm the actual is correct.
    printf '%s\n' "$(jq -nc \
      --arg name "$name" \
      --arg input "$input" \
      --arg expected "$actual" \
      '{name: $name, input: $input, expected: $expected}')"
    continue
  fi

  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=$'\n----\n'"FAIL: $name"$'\n'"  input:    $input"$'\n'"  expected: $expected"$'\n'"  actual:   $actual"
  fi
done < "$VECTORS"

if [[ "$MODE" == "generate" ]]; then
  exit 0
fi

echo "redaction tests: $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
  printf '%s\n' "$FAILURES" >&2
  exit 1
fi
