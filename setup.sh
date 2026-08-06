#!/bin/bash

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WISER_CLAUDE_DIR="$HOME/Projects/Wiser/.claude"
AGENTS_LINK="$WISER_CLAUDE_DIR/agents"
ZSHRC="$HOME/.zshrc"

SHELL_FUNCTION='
# wisersite-claude-config: pull latest Wiser agents before launching Claude
function claude() {
  git -C ~/Projects/Wiser/wisersite-claude-config pull --quiet
  command claude "$@"
}'

echo "Setting up wisersite-claude-config..."

# Create .claude dir if it doesn't exist
mkdir -p "$WISER_CLAUDE_DIR"

# Create symlink (remove existing dir/link if present)
if [ -L "$AGENTS_LINK" ]; then
  echo "Removing existing symlink at $AGENTS_LINK"
  rm "$AGENTS_LINK"
elif [ -d "$AGENTS_LINK" ]; then
  echo "Error: $AGENTS_LINK exists as a real directory. Move or delete it first."
  exit 1
fi

ln -s "$REPO_DIR/agents" "$AGENTS_LINK"
echo "Symlink created: $AGENTS_LINK -> $REPO_DIR/agents"

# Append shell function to ~/.zshrc if not already present
if grep -q "wisersite-claude-config" "$ZSHRC" 2>/dev/null; then
  echo "Shell function already present in $ZSHRC — skipping."
else
  echo "$SHELL_FUNCTION" >> "$ZSHRC"
  echo "Shell function appended to $ZSHRC"
fi

echo ""
echo "Setup complete. Run: source ~/.zshrc"
