# Wiser Site - Project Knowledge

Single-page shared context loaded for every Claude session. Keep it short; point
to deeper docs rather than duplicating them. If you add to this file, ask yourself:
"would a new dev on their first ticket genuinely need this to make the right call?"
If not, leave it out. This file loads into every session; length is a tax on every
conversation.

Sources of truth that this file points to:
- Wiser-wide architecture decisions: `docs/ADR/` in this repo.
- Coding rules + tenant isolation + DoD: `guardrails/DEVELOPMENT_GUARDRAILS.md` in this repo.
- Repo-specific detail + gotchas: each repo's own `CLAUDE.md` and `docs/ADR/`.

---

## What Wiser is building

Wiser is a creative agency pivoting to a product company. **Wiser Site** is a
white-label recruitment analytics + CMS platform sold to enterprise clients
(Next, NBCU, Emirates, Etihad, etc.) as a subscription product. Delivery is
fixed-price with a financial penalty on slippage; features are sold before
they ship.

Three product surfaces:
- **CMS** - Payload-based admin where clients author careers-site content.
- **Analytics dashboard** - widget-based view of GA4 + Search Console + ATS data.
- **Product AI** - Content Generation, Content Grading, Tone of Voice, AI
  Insights. Vertex-hosted Claude via a shared pattern (see below).

**Tier matters.** Pro vs Enterprise controls which widgets, AI features, and
token caps a tenant gets. Features are resolved at runtime from tenant/tier
config; nothing is hardcoded on/off.

---

## Repos

All repos live under `github.com/wearewiser`.

| Repo | What it is |
|---|---|
| `wisersite-and-payload-plugin` | Shared Payload CMS plugin; dashboard widgets; tenant-scoped data fetchers; AI widget consumers |
| `wisersite-data-fetching-gcp-functions` | GCP Cloud Functions + Jobs: ingestion (ATS, analytics), `gold-to-postgres` loader, AI jobs (daily insights, content grading, content generation, tone-of-voice) |
| `wisersite-data-layer` | Dataform / BigQuery SQL for bronze -> silver -> gold |
| `wiser-site-terraform` | All GCP infrastructure, per-tenant modules, IAM, tenant registry (`tenants.yaml`) |
| `wisersite-data-api-layer` | Legacy NestJS API (ex-`roadmap-svc`); widget serving moved out of it. Being wound down. Do not build new widget paths through it. |
| `wisersite-claude-config` | This repo: shared agents, guardrails, cross-repo ADRs, user-invoked skills, reusable CI workflow |
| `wisersite-<tenant>` | One per tenant (e.g. `wisersite-next`, `wisersite-demo`, `wisersite-roadmap`): the deployed Payload backend; own Docker image, Cloud Run deployment, service account |

**Poly-repo on purpose.** A monorepo was proposed and rejected: the plugin is a
published package with different concerns from the API layer and data pipeline.
Shared assets (agents, skills, guardrails, cross-repo ADRs) live here in
`wisersite-claude-config` and are distributed via `setup.sh` symlinks.

---

## Core architecture

```
Sources ─┐
 Workday │
 Oracle   ├──► Cloud Run (per-source fn) ──► GCS ──► BigQuery ──► gold-to-postgres ──► per-tenant Postgres ──► Widgets
 SR etc.  │                                        (Dataform:            (Cloud Run Job)        (Payload plugin)
 CSV ─────┘                                         bronze→silver→gold)
 GA4 ────────────────── direct connector ──────────►
 Search Console ──────── direct connector ─────────►

AI Cloud Run Functions (Vertex → Claude) read from BigQuery, write back to
BigQuery, replicated to Postgres by the same gold loader. Widgets read Postgres.
```

**Medallion in BigQuery.** One dataset per tenant (and per sub-tenant). Each
dataset has bronze (raw) / silver (cleansed) / gold (aggregated, one per widget
area). Dataform owns the SQL.

**Widgets read Postgres, not BigQuery.** `gold-to-postgres` replicates gold
tables daily to a per-tenant Postgres DB. Widgets use
`getTenantDataSource(tenantKey)` from the plugin's `src/tenantSql/`; it resolves
per-tenant connection via Parameter Manager and fails closed in production if
the key isn't on `ALLOWED_TENANTS`. **Use this for any new server-side feature
that needs tenant data, including AI features.**

**Config vs secrets.** GCP Parameter Manager holds non-secret per-tenant config
(API key references via `__REF__()`, feature flags, tier). GCP Secret Manager
holds actual secrets. Never hardcode either; see
`guardrails/DEVELOPMENT_GUARDRAILS.md`.

**Everything in GCP, region `europe-west1`.** Haiku 4.5 quota confirmed here.

**Cloudflare WAF fronts `*.wiser.site`.** Any outbound HTTP client we write
must set an honest `User-Agent` (`<service-name>/<version> (+<owner-url>)`)
or the WAF returns 403.

---

## Tenancy model

- **Tenant = brand + language.** A different locale/domain is a separate tenant.
- Sub-brands (e.g. VS under Next) are **flat first-class tenants**, not nested.
  Each gets its own Postgres DB and its own service-account scope.
- **Tenant key** is stable and lowercase, format `<tenant>-<subtenant>` (e.g.
  `demo-demo`, `next-next`). Case and separators must match exactly between
  Payload and `tenants.yaml` or lookups silently miss.
- Isolation sits at two layers:
  1. **IAM** - per-tenant service accounts are scoped to their own dataset/DB;
     wrong-tenant queries are denied by GCP.
  2. **Code** - `getTenantDataSource` fails closed on unknown keys.
- **Feature entitlement.** Which widgets / AI features a tenant sees is resolved
  at runtime from centralised tenant/tier config; nothing is hardcoded on/off.
  **Enforce server-side (API layer), not just by hiding UI.** Deny by default:
  if config is missing or unreadable, the feature is off (fail closed). See
  `guardrails/DEVELOPMENT_GUARDRAILS.md` section 7.

---

## Product AI pattern

Every product AI feature follows this pattern. Build on it; do not reinvent.

- **Generation runs in a Cloud Run Function or Job** in
  `wisersite-data-fetching-gcp-functions`. Two trigger patterns across
  features; shared provider / validator / prompt-loader code, different entry
  points:
    - **Scheduled Jobs:** `content-grading` (Cloud Scheduler, weekly Mon 03:xx
      UTC) and `ai-insights` (Cloud Scheduler, daily 06:45 UTC).
    - **HTTP on-demand Functions:** `tone-of-voice` and `content-generation`,
      invoked by the Payload backend when a user interacts with the CMS.
    - No EventArc / Pub/Sub / BigQuery-completion triggers in play today.
- **LLM path:** Vertex-hosted Claude, authed by GCP IAM per-service-account.
  ADR `0001-llm-path-vertex-hosted-claude.md`. Model: Claude Haiku 4.5 on
  `europe-west1`.
- **Shared code** (provider, validator, prompt loader) lives in `python-shared/`
  in the Cloud Functions repo.
- **Validator is Pydantic + bounded retry** (max 3 retries). On persistent
  failure: fail gracefully - widget does not render; never surface a technical
  error to the end user. Retry carries the rejection reason back to the model.
- **Prompts are Markdown files in Git**, versioned per feature. No DB-backed
  prompt registry.
- **Regression tests: promptfoo on CircleCI**, triggered by prompt or
  model-version changes.
- **Storage flow.** AI writes results to BigQuery (`ai_*` tables, append-only =
  audit). `gold-to-postgres` replicates the current snapshot to Postgres.
  Widgets read Postgres.
- **Rules first, Claude second.** Deterministic rules decide what fires; Claude
  only phrases the human-readable copy. No invented figures; schema-enforced
  output; evidence quotes required for negative findings. Scoring is code; the
  LLM never sets a grade.
- **Payload backend callers** must use `tenant_id` from the server session
  (never the browser), HTTP timeout >= 120 s, treat any non-200 as failure,
  no auto-retry (the Function handles retry internally).

---

## Environments and release

| Env | Also called | Notes |
|---|---|---|
| `devl` | alpha, internal dev | CMS + frontend; team work lands here first |
| `beta` | staging | **Frontend only**, pointed at the production CMS |
| `production` | prod | Frontend + CMS |

GKE cluster + all Cloud Run in `europe-west1`.

Release model varies per repo; always check the repo's own docs. Shared shape:

- Git Flow: feature branches off the repo's trunk, PR back in.
- Backend tag-driven deploys: `x.y.z-alpha.N` -> devl; `x.y.z` -> staging + prod.
- Client-site releases follow a separate per-tenant process; coordinate with
  Wiser ops.

**CircleCI guardrails on every pipeline:**
- `npm audit --production --audit-level=critical`
- gitleaks pre-build
- Trivy image scan inside deploy, between push and GitOps sync
- Manual `Approve Deploy` gate on every `release/1` deploy
- `kubectl rollout status` with automatic `rollout undo` on failure

---

## Branch conventions (differ per repo - verify before branching)

| Repo | Trunk | Branch style |
|---|---|---|
| `wisersite-and-payload-plugin` | `develop` | `feature/WP23-XXX-slug` |
| `wisersite-data-fetching-gcp-functions` | `develop` | `feature/WP23-XXX-slug` |
| `wisersite-data-layer` | `main` | **underscore**, e.g. `fix_WP23-XXX_slug` |
| `wiser-site-terraform` | `main` | `feature/WP23-XXX-slug` |
| `wisersite-claude-config` | `develop` | `feature/WP23-XXX-slug` or `chore/...` |

Note: `wisersite-and-payload-plugin` has **no `main` branch**; always branch off
`develop`. When in doubt, invoke the `branch-guardian` agent. Do not guess.

---

## If X breaks, look here

| Symptom | Likely cause / where to look |
|---|---|
| Widget renders "Not graded yet" / empty | `gold-to-postgres` loader hasn't run for the tenant, or `content_grading` flag is off in the tenant registry. Check the Scheduler entry + `tenants.yaml`. |
| HTTP 403 on a call to a `*.wiser.site` URL | Cloudflare WAF blocked the default User-Agent. Set an explicit UA on the outbound client. |
| "No objects passed to apply" in CircleCI deploy | `Sync GitOps Repo` step produced an empty manifest. Pin `google/cloud-sdk`; use the empty-file guard. |
| Pod restarts with `ENOENT` on `package.json` | Production Dockerfile stage missing `WORKDIR /usr/src/app` + explicit `COPY package.json` from the builder. |
| New tenant's Cloud Run Job runs but writes 0 rows | Job still on Google's sample image because CI publish ran before the Job existed. `gcloud run jobs update` to the real alpha tag (needs `run.jobs.update`; usually ops). |
| SR / other ATS pulls silently stop | Vendor-side report changed/removed. Check alerts in `data-monitors` Slack channel. Loud failure is the rule; any silent skip is a bug. |
| Tenant data in the wrong dataset | `getTenantDataSource` resolves via `ALLOWED_TENANTS`; check Parameter Manager + the plugin's tenant resolution path. |
| Payload admin save doesn't invalidate cached data | `revalidateTag(tag, 'max')` is stale-while-revalidate. Use `revalidateTag(tag, { expire: 0 })` in afterChange hooks; `updateTag` throws in Route Handlers. See `src/utils/cache/tenantCacheTags.ts`. |
| Mongo E11000 not detected in a backfill migration | Payload's mongoose adapter wraps it as `ValidationError` with no `code`. Re-query after create fails; benign if the doc now exists. |
| A Payload field silently resets on sibling edit | A field named `updatedAt` collides with Payload's auto-timestamp. Rename it (`revisedAt` etc.) and translate at the loader. |
| Alerts not firing | Alerts route to `data-monitors` Slack first, PagerDuty as escalation. Follow the uniform `<area> - <subject>` naming pattern. |
| Jira MCP errors with "needs authentication" | OAuth token expired. Open a Claude session, load `mcp__atlassian__authenticate` via ToolSearch, complete the browser flow. |
| Activity-log entries not landing in Logs Explorer | Check `gcloud auth list --filter=status:ACTIVE`, confirm cwd is under `~/Projects/Wiser/`, and the current git branch has `WP23-\d+` in it. The hook writes a one-line stderr warning on the first failure per session. Full troubleshooting in `.claude/hooks/README.md`. |

---

## Terminology - confusion points

- **"Frontend"** - Wiser ops mean the public careers site; the delivery team
  mean the analytics dashboard. Always qualify.
- **"CMS"** - the Payload admin interface. Also where dashboard widgets are
  configured.
- **"Widget Service" / "Widget Admin"** - the admin-dashboard layer that
  toggles widgets per tenant. Not an API.
- **"Component" vs "Widget"** - Components build client-facing careers pages
  (from the shared component library). Widgets are dashboard-only analytics
  modules. They do not share a library.
- **"Agent Platform" / "Gemini Enterprise Agent Platform"** - Google's
  platform-layer rebrand of Vertex Model Garden. The model is still Claude.
- **"roadmap"** in a repo name (e.g. `wisersite-roadmap`) is just that
  tenant's identifier, not a feature.

---

## Working with Claude on this project

Shared agents (loaded automatically in every repo under `~/Projects/Wiser/`):

- `branch-guardian` - run before any file change. Always verify with
  `git branch --show-current` after it reports success.
- `dor-guardian` - run before starting a ticket.
- `dod-guardian` - run before raising a PR.
- `secrets-guardian` - runs before **every** git commit, not just commits that
  touch credentials or config (accidentally-introduced secrets land in
  unrelated changes too).
- `ticket-planner` - produces a technical implementation plan for a Jira ticket
  before code is written.
- `design-fidelity-reviewer` - run after any UI / front-end implementation task.
  Compares the built UI against the project's designs (CSS, layout, structure,
  colour, typography, spacing) via source inspection and screenshots, auto-fixes
  safe discrepancies, flags the rest.

User-invoked skills:

- `/user-story-writer` - draft, amend, split, or tidy Wiser user stories from
  Claude Design canvases, Jira tickets, screenshots, meeting notes, transcripts.

Shared hooks (merged into `~/.claude/settings.json` by `setup.sh`, no-op outside
`~/Projects/Wiser/`):

- `activity-log` - one Cloud Logging entry per Claude tool call, written to
  `devl-claude-agent-activity` on `wiser-mainframe` under the invoking
  developer's own `gcloud auth` account. Ticket id extracted from the current
  git branch (`WP23-\d+`); non-ticket branches silently skip. Payload shape,
  action enum, severity, and redaction rules pinned in `schemas/activity_log.md`.
  Needs `jq` and `gcloud` on PATH; hook never fails a tool call. Incident
  lookup: `logName="projects/wiser-mainframe/logs/devl-claude-agent-activity"
  AND jsonPayload.ticket_id="WP23-NNN"` in Logs Explorer.

Full ruleset (what Claude will and will not do, tenant isolation, no-PII,
breach handling, DoD): `guardrails/DEVELOPMENT_GUARDRAILS.md`.

Cross-repo architecture decisions: `docs/ADR/` in this repo.

Repo-specific decisions and local gotchas: each repo's own `CLAUDE.md` and
`docs/ADR/`.

---

## Updating this document

- PR-reviewed; anyone can propose a change.
- **Keep it terse.** Feature-specific detail belongs in the ticket or the
  owning repo's `CLAUDE.md`. Decisions that shape future work belong in an ADR
  and are referenced from here.
- When an architectural decision changes, update this file in the same PR as
  the ADR.
- **Rough budget: ~300 lines / ~3k tokens.** Not a hard cap; a soft ceiling to
  make additions a deliberate choice. If a new entry pushes the file over,
  look for something older to trim or move to an ADR first.

### For Claude: prompting an update

At PR-raise time (i.e. when the developer is about to push and open a PR, or
has just asked `dod-guardian` to check a ticket), check whether the change
being shipped introduces any of:

- a new architectural decision (region, framework, pattern, provider)
- a new cross-repo touch or a new repo in play
- a new gotcha worth adding to the "If X breaks, look here" table
- a new piece of terminology that could confuse the next reader
- a rename, trunk change, or branch-convention change on any repo

If yes, ask the developer: "this change looks like it introduces X — should
PROJECT_KNOWLEDGE.md be updated? If so I can draft the diff." Propose a
concrete one-line entry under the right existing section rather than a prose
summary. If no, say nothing — do not ask on routine commits or PRs.

Never auto-commit a change to this file; always confirm the wording with the
developer first.
