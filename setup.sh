#!/bin/bash

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WISER_CLAUDE_DIR="$HOME/Projects/Wiser/.claude"
AGENTS_LINK="$WISER_CLAUDE_DIR/agents"
SKILLS_LINK="$WISER_CLAUDE_DIR/skills"
ADR_LINK="$WISER_CLAUDE_DIR/adr"
GUARDRAILS_LINK="$WISER_CLAUDE_DIR/guardrails"
HOOKS_LINK="$WISER_CLAUDE_DIR/hooks"
USER_SETTINGS="$HOME/.claude/settings.json"
PROJECT_KNOWLEDGE_LINK="$WISER_CLAUDE_DIR/PROJECT_KNOWLEDGE.md"
ZSHRC="$HOME/.zshrc"

BEGIN_MARK='# BEGIN wisersite-claude-config'
END_MARK='# END wisersite-claude-config'

SHELL_FUNCTION="$BEGIN_MARK
# Pull latest Wiser agents, skills, ADRs, guardrails, and project knowledge before launching Claude.
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

# Create hooks symlink (activity-log + any future shared hooks). Mirrors
# the shape of the four symlinks above. Hooks are discovered by Claude
# Code sessions in any Wiser repo via the shared settings.json below.
if [ -L "$HOOKS_LINK" ]; then
  echo "Removing existing symlink at $HOOKS_LINK"
  rm "$HOOKS_LINK"
elif [ -d "$HOOKS_LINK" ]; then
  echo "Error: $HOOKS_LINK exists as a real directory. Move or delete it first."
  exit 1
fi

ln -s "$REPO_DIR/.claude/hooks" "$HOOKS_LINK"
echo "Symlink created: $HOOKS_LINK -> $REPO_DIR/.claude/hooks"

# Create project-knowledge symlink (file-level, not folder). Unlike the four
# folder symlinks above, PROJECT_KNOWLEDGE.md is a single file at the repo
# root, so the symlink points at the file directly. Handle existing symlink
# or real file.
if [ -L "$PROJECT_KNOWLEDGE_LINK" ]; then
  echo "Removing existing symlink at $PROJECT_KNOWLEDGE_LINK"
  rm "$PROJECT_KNOWLEDGE_LINK"
elif [ -d "$PROJECT_KNOWLEDGE_LINK" ]; then
  echo "Error: $PROJECT_KNOWLEDGE_LINK exists as a real directory. Move or delete it first."
  echo "       (If left in place, 'ln -s' would silently create the link INSIDE the"
  echo "       directory and the CLAUDE.md import would not resolve.)"
  exit 1
elif [ -e "$PROJECT_KNOWLEDGE_LINK" ]; then
  echo "Error: $PROJECT_KNOWLEDGE_LINK exists as a real file. Move or delete it first."
  exit 1
fi

ln -s "$REPO_DIR/PROJECT_KNOWLEDGE.md" "$PROJECT_KNOWLEDGE_LINK"
echo "Symlink created: $PROJECT_KNOWLEDGE_LINK -> $REPO_DIR/PROJECT_KNOWLEDGE.md"

# Wire the guardrails AND project knowledge into Claude sessions by importing
# them from the Wiser project-level CLAUDE.md (auto-discovered by any session
# under ~/Projects/Wiser/). The symlinks above make the files available on
# disk; these imports make Claude actually load them.
WISER_CLAUDE_MD="$HOME/Projects/Wiser/CLAUDE.md"
GUARDRAILS_IMPORT="@.claude/guardrails/DEVELOPMENT_GUARDRAILS.md"
PROJECT_KNOWLEDGE_IMPORT="@.claude/PROJECT_KNOWLEDGE.md"

append_import_if_missing() {
  local import_line="$1"
  local label="$2"
  if grep -qxF "$import_line" "$WISER_CLAUDE_MD"; then
    echo "$label import already present in $WISER_CLAUDE_MD, skipping."
  else
    printf '\n%s\n' "$import_line" >> "$WISER_CLAUDE_MD"
    echo "$label import appended to $WISER_CLAUDE_MD"
  fi
}

if [ -f "$WISER_CLAUDE_MD" ]; then
  append_import_if_missing "$GUARDRAILS_IMPORT" "Guardrails"
  append_import_if_missing "$PROJECT_KNOWLEDGE_IMPORT" "Project knowledge"
else
  cat > "$WISER_CLAUDE_MD" <<EOF
# Wiser project CLAUDE.md

Project-level guidance applied to every Wiser repo via Claude Code's
hierarchical CLAUDE.md discovery.

$GUARDRAILS_IMPORT
$PROJECT_KNOWLEDGE_IMPORT
EOF
  echo "Created $WISER_CLAUDE_MD with the guardrails and project knowledge imports."
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

# ---------------------------------------------------------------------------
# Claude activity-log hooks: merge into user-level ~/.claude/settings.json.
# Soft-fails so an optional observability hook never blocks a fresh setup;
# the critical install steps (symlinks, CLAUDE.md imports, zshrc wrapper)
# have already run above. On a missing jq or a malformed existing
# settings.json, print a warning and continue. The hook is a best-effort
# audit tool, not a hard requirement for the rest of the agentic rig.
# ---------------------------------------------------------------------------
install_activity_log_hooks() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "  Warning: jq is not on PATH. Activity-log hooks not merged into"
    echo "           $USER_SETTINGS. Install jq (brew install jq) and re-run"
    echo "           setup.sh when convenient; the rest of the agentic rig"
    echo "           is unaffected."
    return 0
  fi

  if ! mkdir -p "$(dirname "$USER_SETTINGS")" 2>/dev/null; then
    echo "  Warning: cannot create $(dirname "$USER_SETTINGS")."
    echo "           Activity-log hooks not merged; rest of the agentic"
    echo "           rig is unaffected."
    return 0
  fi

  local existing_content='{}'
  if [ -f "$USER_SETTINGS" ]; then
    existing_content="$(cat "$USER_SETTINGS")"
    if ! printf '%s' "$existing_content" | jq empty 2>/dev/null; then
      echo "  Warning: $USER_SETTINGS exists but is not valid JSON."
      echo "           Activity-log hooks not merged. Fix the file by hand"
      echo "           (or move it aside) and re-run setup.sh. The rest of"
      echo "           the agentic rig is unaffected."
      return 0
    fi
  fi

  # Matches the symlink-branch pattern below: `|| true` keeps the
  # assignment non-fatal under `set -e` (mktemp failures: disk full,
  # bad $TMPDIR), empty-value check routes into the standard
  # warn-and-return soft-fail path.
  local settings_tmp=""
  settings_tmp="$(mktemp "${USER_SETTINGS}.XXXXXX" 2>/dev/null)" || true
  if [ -z "$settings_tmp" ]; then
    echo "  Warning: could not create a tempfile next to $USER_SETTINGS."
    echo "           Activity-log hooks not merged; rest of the agentic"
    echo "           rig is unaffected."
    return 0
  fi
  if ! printf '%s' "$existing_content" | jq \
    --arg hooks_link "$HOOKS_LINK" '
    # Strip our activity-log entries at the single-hook granularity, not
    # the whole matcher group. If a dev added an unrelated hook (security
    # check, auditor, etc) into the same matcher group alongside ours, we
    # want to remove only our command from that group without wiping
    # theirs. Groups that end up with no surviving commands are dropped.
    def strip_ours(key):
      (.hooks[key] // []) as $arr
      | .hooks[key] = (
          $arr
          | map(.hooks |= map(select((.command // "") | contains($hooks_link + "/activity-log.sh") | not)))
          | map(select((.hooks // []) | length > 0))
        );
    def add_ours(key; phase):
      .hooks[key] += [{
        matcher: ".*",
        hooks: [{ type: "command", command: ($hooks_link + "/activity-log.sh " + phase) }]
      }];
    .hooks //= {}
    | strip_ours("PreToolUse")
    | strip_ours("PostToolUse")
    | strip_ours("PostToolUseFailure")
    | add_ours("PreToolUse"; "pre")
    | add_ours("PostToolUse"; "post")
    | add_ours("PostToolUseFailure"; "post-failure")
  ' > "$settings_tmp"; then
    rm -f "$settings_tmp"
    echo "  Warning: jq failed to merge the Claude activity-log hooks into"
    echo "           $USER_SETTINGS. Inspect your jq install and re-run setup"
    echo "           when convenient. The rest of the agentic rig is"
    echo "           unaffected."
    return 0
  fi

  if [ ! -s "$settings_tmp" ]; then
    rm -f "$settings_tmp"
    echo "  Warning: jq produced empty output. Refusing to overwrite"
    echo "           $USER_SETTINGS. The rest of the agentic rig is"
    echo "           unaffected."
    return 0
  fi

  # Preserve a dotfiles-managed symlink. If $USER_SETTINGS is a symlink
  # (chezmoi, stow, yadm, home-manager etc), `mv` would replace the link
  # with a regular file and future dotfiles updates would stop reaching
  # Claude Code. Write atomically to a sibling tempfile next to the
  # symlink's actual target, then `mv` onto the target. A plain
  # `cat > "$USER_SETTINGS"` would truncate the real file BEFORE the
  # write completes, leaving an empty / partial settings.json if the
  # write is interrupted (disk full, signal) and breaking Claude Code
  # until a manual fix.
  if [ -L "$USER_SETTINGS" ]; then
    local link_target
    local real_target
    local real_dir
    local real_tmp=""
    link_target="$(readlink "$USER_SETTINGS")"
    case "$link_target" in
      /*) real_target="$link_target" ;;
      *)  real_target="$(dirname "$USER_SETTINGS")/$link_target" ;;
    esac
    real_dir="$(dirname "$real_target")"
    # setup.sh runs under `set -e`. A bare `real_tmp="$(mktemp ...)"`
    # would terminate the whole script if mktemp failed (read-only
    # target directory, out of inodes), bypassing the warn-and-continue
    # path intended by install_activity_log_hooks(). `|| true` keeps
    # the assignment non-fatal; the following empty-value check then
    # handles it with the standard soft-fail warning.
    real_tmp="$(mktemp "${real_dir}/settings.json.XXXXXX" 2>/dev/null)" || true
    if [ -z "$real_tmp" ]; then
      rm -f "$settings_tmp"
      echo "  Warning: could not create a tempfile next to the symlink"
      echo "           target $real_target. Activity-log hooks not merged;"
      echo "           rest of the agentic rig is unaffected."
      return 0
    fi
    if ! cat "$settings_tmp" > "$real_tmp"; then
      rm -f "$real_tmp" "$settings_tmp"
      echo "  Warning: failed to write $real_tmp. Activity-log hooks not"
      echo "           merged; rest of the agentic rig is unaffected."
      return 0
    fi
    # Final mv wrapped in the same soft-fail shape as every other step
    # above. Under setup.sh's `set -e`, a bare mv would terminate the
    # entire script on failure (target FS full, permissions removed
    # mid-run) and leak both tempfiles. Explicit guard: clean up and
    # return 0 so the "Setup complete" message still prints.
    if ! mv "$real_tmp" "$real_target"; then
      rm -f "$real_tmp" "$settings_tmp"
      echo "  Warning: failed to mv $real_tmp onto $real_target."
      echo "           Activity-log hooks not merged; rest of the agentic"
      echo "           rig is unaffected."
      return 0
    fi
    rm -f "$settings_tmp"
  else
    # Same soft-fail wrapper as the symlink branch above. Under
    # setup.sh's `set -e`, a bare mv terminates the whole script if
    # it fails (target read-only, FS full, permissions changed
    # mid-run); wrap so the user gets a warning and the rest of
    # setup proceeds.
    if ! mv "$settings_tmp" "$USER_SETTINGS"; then
      rm -f "$settings_tmp"
      echo "  Warning: failed to mv $settings_tmp onto $USER_SETTINGS."
      echo "           Activity-log hooks not merged; rest of the agentic"
      echo "           rig is unaffected."
      return 0
    fi
  fi
  echo "  Activity-log hooks merged into: $USER_SETTINGS"
}

echo "Installing Claude activity-log hooks..."
install_activity_log_hooks
echo ""

# Pre-flight check for the Claude activity-log hook (schemas/activity_log.md).
# Non-fatal. The hook itself is best-effort and exits 0 on missing tooling,
# but warning here tells a new install why no entries will land until they
# fix it.
#
# Checks the CLI-auth store (`gcloud auth list`), not ADC. The hook writes
# via `gcloud logging write`, which authenticates using the active CLI
# account; checking ADC here would mask the case where ADC is configured
# but no CLI account is active (writes would silently fail).
echo "Checking Claude activity-log hook prerequisites..."
if ! command -v gcloud >/dev/null 2>&1; then
  echo "  Warning: gcloud is not on PATH. The Claude activity-log hook will"
  echo "           silently skip every write until gcloud is installed and"
  echo "           authenticated against the wiser-mainframe project."
elif ! gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q .; then
  echo "  Warning: no active gcloud account. Run 'gcloud auth login' before"
  echo "           the Claude activity-log hook can write. The hook passes"
  echo "           --project=wiser-mainframe explicitly."
else
  gcloud_project="$(gcloud config get-value project 2>/dev/null || true)"
  if [ "$gcloud_project" != "wiser-mainframe" ]; then
    echo "  Note: gcloud default project is '$gcloud_project', not 'wiser-mainframe'."
    echo "        The hook passes --project=wiser-mainframe explicitly so writes"
    echo "        still land; worth switching the default to avoid confusion"
    echo "        when debugging unrelated gcloud commands."
  else
    echo "  gcloud auth + project: OK"
  fi
fi

echo ""
echo "Setup complete. Run: source ~/.zshrc"
