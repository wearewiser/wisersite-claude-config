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

# Install or refresh the shell function block in ~/.zshrc.
# The block is wrapped in sentinel markers so we can replace it in place on
# re-run (eg when the comment or function body changes in a later version).
if [ -f "$ZSHRC" ] && grep -qxF "$BEGIN_MARK" "$ZSHRC"; then
  awk -v begin="$BEGIN_MARK" -v end="$END_MARK" -v rep="$SHELL_FUNCTION" '
    $0 == begin {in_block=1; print rep; next}
    in_block && $0 == end {in_block=0; next}
    !in_block {print}
  ' "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
  echo "Shell function refreshed in $ZSHRC"
else
  # Fresh install, or legacy install from before sentinels were added. In the
  # legacy case the appended block shadows the older one at shell load time
  # (zsh uses the last function definition); the old block is dead but inert.
  printf '\n%s\n' "$SHELL_FUNCTION" >> "$ZSHRC"
  echo "Shell function appended to $ZSHRC"
fi

echo ""
echo "Setup complete. Run: source ~/.zshrc"
