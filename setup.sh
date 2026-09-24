#!/bin/bash

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WISER_CLAUDE_DIR="$HOME/Projects/Wiser/.claude"
AGENTS_LINK="$WISER_CLAUDE_DIR/agents"
SKILLS_LINK="$WISER_CLAUDE_DIR/skills"
ADR_LINK="$WISER_CLAUDE_DIR/adr"
ZSHRC="$HOME/.zshrc"

SHELL_FUNCTION='
# wisersite-claude-config: pull latest Wiser agents, skills, and ADRs before launching Claude
function claude() {
  git -C ~/Projects/Wiser/wisersite-claude-config pull --quiet
  command claude "$@"
}'

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

# Append shell function to ~/.zshrc if not already present
if grep -q "wisersite-claude-config" "$ZSHRC" 2>/dev/null; then
  echo "Shell function already present in $ZSHRC — skipping."
else
  echo "$SHELL_FUNCTION" >> "$ZSHRC"
  echo "Shell function appended to $ZSHRC"
fi

echo ""
echo "Setup complete. Run: source ~/.zshrc"
