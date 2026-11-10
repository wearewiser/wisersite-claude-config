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
# Match on the common prefix so all historical comment variants are covered:
#   - "# wisersite-claude-config: pull latest Wiser agents before launching Claude"
#   - "# wisersite-claude-config: pull latest Wiser agents and skills before launching Claude"
#   - "# wisersite-claude-config: pull latest Wiser agents, skills, ADRs, and guardrails before launching Claude"
# IMPORTANT: a blind "skip 4 lines after the comment" would corrupt any zshrc
# where the user customised the legacy function (added a line inside it,
# shortened it, etc). Validate the 4 body lines match the pristine historical
# function exactly before deleting; if they do not, leave the block alone and
# warn the user to clean it up manually.
LEGACY_COMMENT_PREFIX="# wisersite-claude-config: pull latest"
LEGACY_BODY_1='function claude() {'
LEGACY_BODY_2='  git -C ~/Projects/Wiser/wisersite-claude-config pull --quiet'
LEGACY_BODY_3='  command claude "$@"'
LEGACY_BODY_4='}'
if [ -f "$ZSHRC" ] && grep -q "^${LEGACY_COMMENT_PREFIX}" "$ZSHRC"; then
  ZSHRC_TMP="$(mktemp)"
  STATUS_TMP="$(mktemp)"
  awk -v prefix="$LEGACY_COMMENT_PREFIX" \
      -v b1="$LEGACY_BODY_1" \
      -v b2="$LEGACY_BODY_2" \
      -v b3="$LEGACY_BODY_3" \
      -v b4="$LEGACY_BODY_4" \
      -v status_file="$STATUS_TMP" '
    index($0, prefix) == 1 {
      comment = $0
      g1 = getline l1
      g2 = getline l2
      g3 = getline l3
      g4 = getline l4
      if (g1 > 0 && g2 > 0 && g3 > 0 && g4 > 0 && \
          l1 == b1 && l2 == b2 && l3 == b3 && l4 == b4) {
        # Pristine historical block - drop all 5 lines.
        next
      }
      # Customized or truncated - preserve every line that was read and flag.
      print comment
      if (g1 > 0) print l1
      if (g2 > 0) print l2
      if (g3 > 0) print l3
      if (g4 > 0) print l4
      print "customized" > status_file
      next
    }
    { print }
  ' "$ZSHRC" > "$ZSHRC_TMP"
  cat "$ZSHRC_TMP" > "$ZSHRC"
  rm "$ZSHRC_TMP"
  if [ -s "$STATUS_TMP" ]; then
    echo "Warning: legacy wisersite-claude-config block in $ZSHRC appears customized"
    echo "         (comment matches, body does not match the historical pristine"
    echo "         function). Left in place to avoid corrupting your shell. The new"
    echo "         sentinel block below shadows it at shell load, so claude() still"
    echo "         resolves to the new function. To fully clean up, delete the stray"
    echo "         block by hand."
  else
    echo "Legacy pre-sentinel wisersite-claude-config block stripped from $ZSHRC"
  fi
  rm "$STATUS_TMP"
fi

# Install or refresh the shell function block in ~/.zshrc.
# The block is wrapped in sentinel markers so we can replace it in place on
# re-run (eg when the comment or function body changes in a later version).
# IMPORTANT: when refreshing, write back through the existing file (append + cat)
# rather than `mv` the temp file over the top; if ~/.zshrc is a symlink managed
# by a dotfiles tool (chezmoi, stow, yadm, home-manager), `mv` would replace the
# symlink with a regular file and future dotfiles updates would stop reaching
# the shell.
#
# Marker counts are computed upfront on every run so malformed states (orphan
# END without matching BEGIN, duplicate markers, wrong order) are caught
# BEFORE we decide between append and refresh. Earlier revisions only validated
# when BEGIN was present, so an orphan END would silently get past the first
# run (fresh-install append branch) and then poison validation on the second.
if [ -f "$ZSHRC" ]; then
  # grep -c prints 0 to stdout AND exits 1 on no-match; the `|| true` suffixes
  # prevent `set -e` from aborting before the validator runs.
  BEGIN_COUNT=$(grep -cxF "$BEGIN_MARK" "$ZSHRC" || true)
  END_COUNT=$(grep -cxF "$END_MARK" "$ZSHRC" || true)
else
  BEGIN_COUNT=0
  END_COUNT=0
fi

if [ "$BEGIN_COUNT" -eq 0 ] && [ "$END_COUNT" -eq 0 ]; then
  # Fresh install path. No sentinel markers of any kind in zshrc.
  printf '\n%s\n' "$SHELL_FUNCTION" >> "$ZSHRC"
  echo "Shell function appended to $ZSHRC"
elif [ "$BEGIN_COUNT" -eq 1 ] && [ "$END_COUNT" -eq 1 ]; then
  # Refresh path. Exactly one well-formed block; validate ordering before the
  # awk refresh, then replace in place.
  BEGIN_LINE=$(grep -nxF "$BEGIN_MARK" "$ZSHRC" | head -n1 | cut -d: -f1)
  END_LINE=$(grep -nxF "$END_MARK" "$ZSHRC" | head -n1 | cut -d: -f1)
  if [ "$BEGIN_LINE" -ge "$END_LINE" ]; then
    echo "Error: $ZSHRC has sentinel markers in the wrong order"
    echo "       (BEGIN on line $BEGIN_LINE, END on line $END_LINE). Refusing"
    echo "       to refresh because the awk replace would silently delete"
    echo "       lines between the stray END and end-of-file. Restore the"
    echo "       block to a single BEGIN/END pair in the correct order"
    echo "       (or delete the whole wisersite-claude-config block) and re-run."
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
  # Any other combination: orphan BEGIN or END without its partner, duplicate
  # markers, etc. Refuse to touch the file; the awk refresh would risk data
  # loss and the fresh-install append would compound the existing problem.
  echo "Error: $ZSHRC has an unbalanced or malformed wisersite-claude-config"
  echo "       block (expected exactly one '$BEGIN_MARK' and exactly one"
  echo "       '$END_MARK'; found $BEGIN_COUNT BEGIN and $END_COUNT END markers)."
  echo "       Refusing to run until the block is restored to a single BEGIN/END"
  echo "       pair or removed entirely."
  exit 1
fi

echo ""
echo "Setup complete. Run: source ~/.zshrc"
