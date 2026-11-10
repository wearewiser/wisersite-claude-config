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
