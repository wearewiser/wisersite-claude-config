#!/bin/bash

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WISER_CLAUDE_DIR="$HOME/Projects/Wiser/.claude"
AGENTS_LINK="$WISER_CLAUDE_DIR/agents"
SKILLS_LINK="$WISER_CLAUDE_DIR/skills"
ADR_LINK="$WISER_CLAUDE_DIR/adr"
GUARDRAILS_LINK="$WISER_CLAUDE_DIR/guardrails"
ZSHRC="$HOME/.zshrc"

BEGIN_MARK='# BEGIN wisersite-claude-config'
END_MARK='# END wisersite-claude-config'

SHELL_FUNCTION="$BEGIN_MARK
# Pull latest Wiser agents, skills, ADRs, and guardrails before launching Claude.
function claude() {
  git -C ~/Projects/Wiser/wisersite-claude-config pull --quiet
  command claude \"\$@\"
}
$END_MARK"

echo "Setting up wisersite-claude-config..."

# Create .claude dir if it doesn't exist
mkdir -p "$WISER_CLAUDE_DIR"

# Create agents symlink (remove existing dir/link if present)
if [ -L "$AGENTS_LINK" ]; then
  echo "Removing existing symlink at $AGENTS_LINK"
  rm "$AGENTS_LINK"
elif [ -d "$AGENTS_LINK" ]; then
  echo "Error: $AGENTS_LINK exists as a real directory. Move or delete it first."
  exit 1
fi

ln -s "$REPO_DIR/agents" "$AGENTS_LINK"
echo "Symlink created: $AGENTS_LINK -> $REPO_DIR/agents"

# Skills symlink (skills live under .claude/skills in this repo)
if [ -L "$SKILLS_LINK" ]; then
  echo "Removing existing symlink at $SKILLS_LINK"
  rm "$SKILLS_LINK"
elif [ -d "$SKILLS_LINK" ]; then
  echo "Error: $SKILLS_LINK exists as a real directory. Move or delete it first."
  exit 1
fi

ln -s "$REPO_DIR/.claude/skills" "$SKILLS_LINK"
echo "Symlink created: $SKILLS_LINK -> $REPO_DIR/.claude/skills"

# Create adr symlink (remove existing dir/link if present)
if [ -L "$ADR_LINK" ]; then
  echo "Removing existing symlink at $ADR_LINK"
  rm "$ADR_LINK"
elif [ -d "$ADR_LINK" ]; then
  echo "Error: $ADR_LINK exists as a real directory. Move or delete it first."
  exit 1
fi

ln -s "$REPO_DIR/docs/ADR" "$ADR_LINK"
echo "Symlink created: $ADR_LINK -> $REPO_DIR/docs/ADR"

# Create guardrails symlink (remove existing dir/link if present)
if [ -L "$GUARDRAILS_LINK" ]; then
  echo "Removing existing symlink at $GUARDRAILS_LINK"
  rm "$GUARDRAILS_LINK"
elif [ -d "$GUARDRAILS_LINK" ]; then
  echo "Error: $GUARDRAILS_LINK exists as a real directory. Move or delete it first."
  exit 1
fi

ln -s "$REPO_DIR/guardrails" "$GUARDRAILS_LINK"
echo "Symlink created: $GUARDRAILS_LINK -> $REPO_DIR/guardrails"

# Wire the guardrails into Claude sessions by importing them from the
# Wiser project-level CLAUDE.md (auto-discovered by any session under
# ~/Projects/Wiser/). The symlink above makes the file available on disk;
# this import makes Claude actually load it.
WISER_CLAUDE_MD="$HOME/Projects/Wiser/CLAUDE.md"
GUARDRAILS_IMPORT="@.claude/guardrails/DEVELOPMENT_GUARDRAILS.md"

if [ -f "$WISER_CLAUDE_MD" ] && grep -qxF "$GUARDRAILS_IMPORT" "$WISER_CLAUDE_MD"; then
  echo "Guardrails import already present in $WISER_CLAUDE_MD, skipping."
elif [ -f "$WISER_CLAUDE_MD" ]; then
  printf '\n%s\n' "$GUARDRAILS_IMPORT" >> "$WISER_CLAUDE_MD"
  echo "Guardrails import appended to $WISER_CLAUDE_MD"
else
  cat > "$WISER_CLAUDE_MD" <<EOF
# Wiser project CLAUDE.md

Project-level guidance applied to every Wiser repo via Claude Code's
hierarchical CLAUDE.md discovery.

$GUARDRAILS_IMPORT
EOF
  echo "Created $WISER_CLAUDE_MD with the guardrails import."
fi

# One-time migration: strip the pre-sentinel claude() block if present.
# Early versions of setup.sh appended an un-marked block (comment + 4-line
# function); legacy users would otherwise accrue two claude() definitions
# permanently. Only runs on first upgrade from the pre-sentinel version.
LEGACY_COMMENT="# wisersite-claude-config: pull latest Wiser agents, skills, ADRs, and guardrails before launching Claude"
if [ -f "$ZSHRC" ] && grep -qxF "$LEGACY_COMMENT" "$ZSHRC"; then
  ZSHRC_TMP="$(mktemp)"
  awk -v target="$LEGACY_COMMENT" '
    $0 == target { skip = 4; next }
    skip > 0 { skip--; next }
    { print }
  ' "$ZSHRC" > "$ZSHRC_TMP"
  cat "$ZSHRC_TMP" > "$ZSHRC"
  rm "$ZSHRC_TMP"
  echo "Legacy pre-sentinel wisersite-claude-config block stripped from $ZSHRC"
fi

# Install or refresh the shell function block in ~/.zshrc.
# The block is wrapped in sentinel markers so we can replace it in place on
# re-run (eg when the comment or function body changes in a later version).
# IMPORTANT: when refreshing, write back through the existing file (append + cat)
# rather than `mv` the temp file over the top; if ~/.zshrc is a symlink managed
# by a dotfiles tool (chezmoi, stow, yadm, home-manager), `mv` would replace the
# symlink with a regular file and future dotfiles updates would stop reaching
# the shell.
if [ -f "$ZSHRC" ] && grep -qxF "$BEGIN_MARK" "$ZSHRC"; then
  # Safety check: the awk refresh below assumes exactly one well-formed
  # sentinel block (one BEGIN followed by one END). Anything else risks data
  # loss - a missing END, a duplicate BEGIN, or markers in the wrong order
  # would all leave `in_block` stuck at 1 at some point and silently delete
  # lines up to EOF. Refuse to run in any of those states.
  # Note: grep -c prints 0 to stdout AND exits 1 on no-match; the `|| true`
  # suffixes prevent `set -e` from aborting before the validator runs.
  BEGIN_COUNT=$(grep -cxF "$BEGIN_MARK" "$ZSHRC" || true)
  END_COUNT=$(grep -cxF "$END_MARK" "$ZSHRC" || true)
  BEGIN_LINE=$(grep -nxF "$BEGIN_MARK" "$ZSHRC" | head -n1 | cut -d: -f1)
  END_LINE=$(grep -nxF "$END_MARK" "$ZSHRC" | head -n1 | cut -d: -f1)
  if [ "$BEGIN_COUNT" -ne 1 ] || [ "$END_COUNT" -ne 1 ] || [ -z "$END_LINE" ] || [ "$BEGIN_LINE" -ge "$END_LINE" ]; then
    echo "Error: $ZSHRC has an unbalanced or malformed wisersite-claude-config block."
    echo "       Expected exactly one '$BEGIN_MARK' followed by exactly one"
    echo "       '$END_MARK' (found $BEGIN_COUNT BEGIN and $END_COUNT END markers)."
    echo "       Refusing to refresh because the awk block would risk silently"
    echo "       deleting lines between a stray marker and end-of-file. Restore"
    echo "       the block to a single BEGIN/END pair (or delete the whole"
    echo "       wisersite-claude-config block) and re-run."
    exit 1
  fi
  ZSHRC_TMP="$(mktemp)"
  # Pass SHELL_FUNCTION via environment and read via ENVIRON[]. macOS BWK awk
  # rejects newlines in `-v` values with "awk: newline in string" and with
  # `set -e` the whole script aborts here on any re-run. Env-var pass survives
  # the newlines on both GNU awk and macOS awk.
  REP="$SHELL_FUNCTION" awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
    $0 == begin {in_block=1; print ENVIRON["REP"]; next}
    in_block && $0 == end {in_block=0; next}
    !in_block {print}
  ' "$ZSHRC" > "$ZSHRC_TMP"
  cat "$ZSHRC_TMP" > "$ZSHRC"
  rm "$ZSHRC_TMP"
  echo "Shell function refreshed in $ZSHRC"
else
  # Fresh install path. The legacy-block migration above runs first so this
  # branch is only ever reached with a clean zshrc (no pre-sentinel block).
  printf '\n%s\n' "$SHELL_FUNCTION" >> "$ZSHRC"
  echo "Shell function appended to $ZSHRC"
fi

echo ""
echo "Setup complete. Run: source ~/.zshrc"
