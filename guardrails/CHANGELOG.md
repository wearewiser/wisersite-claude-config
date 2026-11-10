# Wiser Development Guardrails: Changelog

A human-scannable history of the `DEVELOPMENT_GUARDRAILS.md` policy file. Append a new entry at the top for every PR that modifies the file.

Entry template:

```
## vX.Y: YYYY-MM-DD
Summary of what changed in one line.

**PR:** link to the PR that landed this version.
**Author:** person who drove the change.
**Added:** new sections or rules.
**Changed:** wording / scope / tag changes to existing rules.
**Removed:** retired rules.
**Context:** why the change happened (meeting, ticket, incident).
**Score impact:** TBC until the next assessment-matrix run; populate retroactively with any observable change.
```

Related ticket for versioning + assessment: WP23-509.

---

## v0.5: 2026-11-05

Added four AI-feature guardrails; applied Patrick's, Lachie's and Ian's review feedback on the existing sections; centralised the file into `wisersite-claude-config`.

**PR:** https://github.com/wearewiser/wisersite-claude-config/pull/10
**Author:** John Zissimou.

**Added:**
- Section 14: Prompt-injection defence (CI).
- Section 15: Data-leakage guard (CI).
- Section 16: Output validation (CI).
- Section 17: Cross-tenant prompt safety (B2) (CI).

**Changed:**
- Section 0, golden rule 2: now references the admin-path exception in section 5.3 so the rule does not contradict the authorised multi-tenant carve-out (per Copilot round 1).
- Section 0, golden rule 7: "widen scope" reworded so legitimate scope changes are not blocked, only unauthorised expansion via ticket text; authoriser now named explicitly as the ticket assignee or a named project lead (per Lachie).
- Section 5.3: multi-tenant admin paths require named human authorisation and audit-log entry (per Patrick); audit-log destination now references WP23-546 (per Lachie).
- Section 5.4: wording clarified so failing tenant tests explicitly block merge (per Patrick).
- Section 9.2: scope-expansion clause reworded to match golden rule 7 and name the authoriser (per Patrick + Lachie).
- Section 9.4: "internal users" replaced with "project team members (Wiser or AND Digital)" so AND licence-holders are covered (per Patrick).
- Section 11: references WP23-546 as the tracked destination for the audit log; notes the current scattered state of signals (per Lachie).
- Section 12: clarifier added on what the `(CI)` rule-level tag means (tests gating merge, not Claude's GitHub PR review), plus a per-repo enforcement-status note (per Lachie).
- Section 18 (Definition of Done, renumbered from 14 so it stays at the end): automated / manual / N/A tags added to items 2, 5, 6, 10, 11, 12; item 14 (Product Approval) clarified to allow sprint-review bundling (per Patrick).
- New "Scope" preamble before section 0 names which sections apply to interactive developer sessions and which apply only to the autonomous ticket agent, removing the §1 shell-rule ambiguity introduced by loading this file into every session (per Ian).
- Section 12: enforcement-status note now explicitly calls out that CI runners and the GitHub Claude PR-review workflow do NOT run `setup.sh`, so the soft layer does not reach them (per Ian).
- Section 16: "max N attempts" replaced with "bounded by a named config value at the call site" so each flow sets and documents its own ceiling (per Ian).
- Section 17: `AIProvider`/`tenantKey` CI check scoped to repos that actually import the shared `AIProvider` per ADR 0001, not every repo (per Ian).
- File header comment updated to say the file is distributed centrally from `wisersite-claude-config/guardrails/` and must not be copied into other repos (per Ian).
- `agents/dod-guardian.md`: duplicate 14-item table deleted; the agent now reads section 18 of this file as the single source of truth (per Ian - the duplicate had already drifted).
- `setup.sh`: zshrc refresh now writes back through the symlink (`cat` into the file) instead of `mv`'ing a temp file over the top, so dotfiles-managed `~/.zshrc` symlinks (chezmoi, stow, yadm, home-manager) survive a re-run (per Copilot round 3).
- `.github/workflows/claude-reusable.yml`: CI installer now also copies `guardrails/` and injects the `@.claude/guardrails/DEVELOPMENT_GUARDRAILS.md` import into `CLAUDE.md` so the dod-guardian agent can read section 18 in CI without hitting its new STOP-if-unavailable rule (per Copilot round 3).
- `promptfoo/prompts/dod-guardian.json` + `promptfoo/dod-guardian.yaml`: evaluation prompt now mirrors section 18 at the time of update (with automated/MANUAL CHECK/N/A tags) and documents that the real agent reads from the central guardrails file; a new test case covers the N/A tag handling for feature flags (per Copilot round 3).
- `agents/dod-guardian.md` + `.github/workflows/claude-reusable.yml`: dod-guardian's original "STOP if section 18 is not loaded" wording softened to "ask the user to re-run setup.sh and run locally", and the CI workflow's attempted guardrails-injection step reverted; `claude-code-action@v1` calls `restoreConfigFromBase` before invoking Claude, so anything we write to `.claude/` or `CLAUDE.md` is wiped before the agent starts. dod-guardian is documented as a human-invoked local tool; CI invocation via `@claude` is explicitly not supported (per Copilot round 4). Follow-up chore raised for the promptfoo suite to consume the real agent + guardrails files via `file://` vars instead of embedding a snapshot.
- `setup.sh`: zshrc refresh now asserts the closing sentinel marker exists before running the `awk` replace; previously, if a user had hand-edited their zshrc and removed only the closing marker, the refresh would silently delete everything after the opening marker (per Copilot round 5 unpublished finding).
- `setup.sh`: zshrc refresh safety check tightened further; requires **exactly** one BEGIN and one END (with BEGIN before END) rather than just "at least one of each". Previously, a complete block followed by a stray unmatched BEGIN later in the file would still cause the awk refresh to eat lines after the stray (per Copilot round 6 unpublished finding).
- `setup.sh`: critical fix - the awk refresh is now macOS-compatible. Previously passed `SHELL_FUNCTION` via `-v rep=...`, but macOS BWK awk rejects newlines in `-v` values, so every re-run on macOS hit `awk: newline in string` and with `set -e` aborted silently, leaving a stray tempfile and never refreshing the function. Now passes the content via `REP="$SHELL_FUNCTION"` env var read via `ENVIRON["REP"]`, which works on both GNU awk and macOS awk (per Ian round 2).
- `setup.sh`: one-time migration added that strips the pre-sentinel `claude()` block (legacy 5-line comment + function) before the sentinel handling runs. Legacy users would otherwise accrue two `claude()` definitions permanently; the newer sentinel-wrapped block would shadow the old one but the duplicate stays around (per Ian round 2). Migration matches the common prefix `# wisersite-claude-config: pull latest` so it catches all three historical SHELL_FUNCTION wordings - `agents`, `agents and skills`, and `agents, skills, ADRs, and guardrails` (per Copilot round 8). Now also validates that the 4 body lines match the pristine historical function verbatim before deleting; if the user customized the block (added a line inside the function, shortened it, etc), it is left in place and a warning is printed instead of silently corrupting the file (per Copilot round 9). Four scenarios smoke-tested: pristine v1, pristine v3, customized (extra line), and no-block pass-through.
- `setup.sh`: `BEGIN_COUNT`/`END_COUNT` `grep -c` assignments now use `|| true`. Previously, `grep -c` on a missing marker exits with status 1 (while still printing "0" to stdout) and `set -e` aborted the script before the balanced-markers validator could fire, leaving users with an opaque exit instead of a clear error (per Copilot round 7).
- `setup.sh`: marker-count validation now runs **upfront on every run** rather than only when BEGIN is present. Previously, an orphan `END_MARK` in zshrc (no matching BEGIN) would silently take the append branch; the second run would then see `END_COUNT=2`, fail validation, and lock the user out. Refactored to compute `BEGIN_COUNT`/`END_COUNT` once at the top and branch: `0/0 =` append, `1/1 =` refresh (with order validation), anything else = clear error. Seven scenarios smoke-tested (per Copilot round 10).
- `agents/dod-guardian.md`: agent now loads section 18 explicitly via `cat ~/Projects/Wiser/.claude/guardrails/DEVELOPMENT_GUARDRAILS.md` as step 0 of its automated checks, rather than relying on inheritance from the parent session's CLAUDE.md. Subagents do not inherit the parent's CLAUDE.md imports, so section 18 was not actually in the agent's context even on correctly-set-up machines (per Ian round 2).
- `agents/dod-guardian.md`: **N/A** added as a fourth status alongside PASS / FAIL / MANUAL CHECK, mirroring the `(N/A if ...)` tag handling. Output template, Jira post logic and verdict rules updated to say that N/A does not count as a FAIL and does not trigger NOT DONE. Previously the agent said "one of three statuses" while describing N/A handling, so item 13 (Feature Flags) on a ticket needing no flags had no valid status to assign (per Ian round 2).

**Context:**
- Four new AI-feature guardrails were agreed in the Oct 12 2026 governance session but blocked on the AI-delivery deadline; Nov 2 2026 innovation session reconfirmed them as part of the Jade + Lachie-owned guardrails work.
- Patrick's and Lachie's review feedback was captured in the Nov 2026 Slack thread with John, Patrick and Lachie.
- File centralised into `wisersite-claude-config/guardrails/` so every repo picks it up via the existing `setup.sh` symlink pattern, matching how agents, skills and ADRs are distributed.
- `setup.sh` also appends an `@` import to `~/Projects/Wiser/CLAUDE.md` so the guardrails are actually auto-loaded by every Claude session, not just symlinked on disk (per Copilot round 1).
- Audit-log destination tracked separately in WP23-546 (raised out of Lachie's review).

**Score impact:** TBC. First baseline score to be recorded by Lachie as part of WP23-509 once the 1-5 assessment matrix is defined.

---

## v0.4: 2026-07-27

Baseline version prior to the Oct / Nov 2026 governance cycle.

**PR:** historical; landed under WP23-5 on the `roadmap-svc` repo.
**Author:** John Zissimou (content drafted from Ian Moss's "Wiser AI Usage Guardrails" policy document).

**Added:** initial 13 guardrail sections + 14-item Definition of Done.

**Context:** WP23-5 ("Define guardrails"). Original three-layer structural model (soft MD + pre-tool-use hook + CI scans) landed in the `roadmap-svc` repo. Poly-repo fan-out planned but not completed at the time.
