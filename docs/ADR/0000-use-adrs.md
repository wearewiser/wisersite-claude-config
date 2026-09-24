---
status: Accepted
date: 2026-09-16
---

# 0000: Use Architecture Decision Records (Wiser-wide)

## Context

Wiser is a poly-repo estate (plugin, data api layer, roadmap, ingestion Cloud Functions, cluster infra, shared Claude config, etc.). Decisions that affect more than one repo (framework choice, LLM path, ingestion pipeline shape, cross-repo interfaces) have no natural home in any single repo's `docs/ADR/` folder.

The `wisersite-data-api-layer/docs/ADR/` folder previously hosted some of these cross-cutting decisions (e.g. "GCP Cloud Functions for ATS/analytics ingestion") because it was where the pattern was first adopted. That service is being wound down, so those decisions need a home that outlives it.

## Decision

Cross-repo architectural decisions are recorded here, in `wisersite-claude-config/docs/ADR/`. This repo is already the single source of truth for shared Claude Code configuration, is symlinked into every Wiser project locally, and is pulled into every repo's CI via the reusable workflow, so ADRs living here are naturally visible to any Claude session in any Wiser repo.

**Scope of this folder:** decisions that affect more than one Wiser repo, or that establish patterns future new repos should follow.

**Not in scope:** decisions specific to a single repo's internal behaviour (e.g. response-shape contracts, module boundaries within one service). Those stay in the individual repo's `docs/ADR/` folder.

Format: Status, Context, Decision, Consequences.
Statuses: Proposed | Accepted | Deprecated | Superseded by [XXXX].

Claude checks this folder before making new decisions to avoid violating agreed approaches, and updates entries when decisions evolve.

## Consequences

- New cross-repo ADRs land here; new repo-scoped ADRs stay in their own repo.
- Content for 0002 (GCP Cloud Functions ingestion) was originally recorded in `wisersite-data-api-layer/docs/ADR/` and has been re-homed here as the authoritative Wiser-wide copy. The api-layer file is left in place untouched; it will disappear naturally when that repo is retired. 0001 in the api layer (endpoints return current + previous period) is api-layer-specific and stays there.
- Any Claude session in any Wiser repo can reach these ADRs via the symlinked `~/Projects/Wiser/.claude/adr/` folder (local) or `.claude/adr/` (CI).
