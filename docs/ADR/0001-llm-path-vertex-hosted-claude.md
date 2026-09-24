---
status: Accepted
date: 2026-09-16
amended: 2026-09-23
ticket: WP23-126
---

# 0001: LLM Path - Vertex-hosted Claude

## Context

Wiser is starting to build product-facing AI features. WP23-175 (Component Insights) is the first; WP23-72 / 73 / 74 are the next wave. WP23-304 is a spike originally scoped assuming Claude via the public Anthropic API.

WP23-126 assessed six readiness dimensions (back-end, guardrails, monitoring, fail-safes, governance, LLM path) and surfaced a genuine trade-off on the LLM path. Two options were shortlisted (Vertex Gemini and Custom RAG were ruled out - Gemini for model-quality gap on synthesis, RAG for scope):

- **Option A: Vertex-hosted Claude (`europe-west1` or EU multi-region).** Same Claude model, accessed via Google's Vertex AI. GCP-native, EU data residency, IAM-based tenant isolation, single-vendor consolidation. Greenfield for Wiser (no existing Vertex quota / IAM per Mikey); realistic ~2-3 weeks extra ramp vs Option B for the first feature.
- **Option B: Anthropic direct (Claude via public API).** ~2 weeks to first shipped feature, matches WP23-175 / WP23-304 as-scoped, minor per-call cost saving. Adds a non-GCP vendor, crosses data to the US, tenant isolation relies on prompt / cache-key discipline rather than IAM.

Reviewer input (Slack thread, 2026-09-11 to 2026-09-16):

- **Lachie (product / commercial)**: soft-lean Option A. "Single-vendor GCP consolidation + governance is definitely something we like." Vertex cost premium is "noise" given projected small user base + irregular AI-feature usage.
- **Stephen (technical)**: lean Option A. Security / tenant isolation and data-region crossover are the deciding factors; Vertex cost premium a small consideration in that light.
- **Patrick**: non-technical on this dimension; happy to proceed.
- **Jade**: in-thread for governance visibility; formal AI-tools approval pass tracked as separate governance follow-up.
- **Ian**: away; no blocker (Stephen has covered the technical view).

## Decision

**Option A - Vertex-hosted Claude, `europe-west1` or EU multi-region.**

- Auth: GCP IAM with per-service-account access (no long-lived Anthropic API key).
- Region: EU multi-region (`eu`). Confirmed by WP23-304 spike (2026-09-22): Haiku 4.5 is not available in `europe-west1`, so the multi-region endpoint is the target.
- Model: latest available Claude via Vertex at time of build (Sonnet-tier for MVP unless quality gap forces Opus). To be validated per-feature in the shared `AIProvider` layer.

## Consequences

- **WP23-175 and WP23-304 re-scope.** WP23-304 changes from "Anthropic direct spike" to "Vertex-hosted Claude spike" (endpoint + IAM instead of API key). Availability/latency validation is done via the WP23-304 spike: `eu` multi-region confirmed.
- **Governance pass required.** Vertex-hosted Claude runs through Jade's AI-tools approval process before it can be used in production.
- **~2-3 wks Vertex ramp cost.** The first AI feature bears the cost of GCP service account setup, Vertex quota requests, endpoint config, plus team ramp on the Vertex SDK. Realistic time-to-first-shipped-feature: ~4-5 weeks total.
- **Tenant isolation lever.** IAM per service account replaces prompt / cache-key discipline as the primary isolation surface. The plugin's `getTenantDataSource` pattern (per-tenant Postgres) remains the tenant-scoped data access mechanism for reads; the Cloud Run function writes AI outputs to the same per-tenant Postgres model.
- **AI generation runs in a shared Cloud Run function, not the plugin.** Locked at architecture session (2026-09-22 pm). A single "silver bullet" Cloud Run function serves all product-facing AI features for MVP: WP23-175 (Component Insights & Recommendations), the WP23-184 AI Insights family (WP23-185 to WP23-191, one story per view), and WP23-74 (Content Grading). Broken apart later only if load or shape demands.
- **Trigger model.** Event-driven off BigQuery gold-layer completion per tenant (not a fixed schedule). The Content Grading Regenerate button reuses the same Cloud Run function on-demand, with job status tracked in a jobs table and "last graded at" surfaced in the UI. No dedicated queue: Cloud Run's built-in retry and horizontal scaling covers it (Mikey's call, over Dumitru's RabbitMQ suggestion).
- **Plugin does the read/display path only.** Following the widget pattern (self-contained module inside `wisersite-and-payload-plugin`), widgets read AI outputs from per-tenant Postgres. The shared `AIProvider` interface lives **inside** the Cloud Run function, not the plugin.
- **AI outputs persist in per-tenant Postgres.** Not just cache: audit-history requirement from in-flight enterprise contracts (Mikey, data-retention clauses); also enables future recommendation-efficacy analytics. Cache TTL = 24 hours.
- **Per-tenant variance is config, not prompts.** The prompt set is shared across tenants; per-tenant tone-of-voice / brand guidelines are injected into shared prompts at generation time.
- **Cost visibility via GCP billing.** No separate Anthropic dashboard to reconcile. AI-specific log-based metrics (token count, cost per tenant, cache hit/miss, validation failure rate) still needed.
- **Model version cadence lags Anthropic direct by days-to-weeks.** Rarely load-bearing, but flagged in case a specific new-Claude feature is time-sensitive.
- **Alt-text microservice (OpenAI) is unchanged by this decision.** Product-facing AI features use Vertex-hosted Claude; the alt-text microservice remains on OpenAI unless separately reassessed.

## Related

- WP23-126 (this assessment).
- WP23-175 (first product-facing AI feature; owns re-scope consumption).
- WP23-304 (spike; owns endpoint + IAM re-scope).
- WP23-7 (Named AI Service Owner; hard governance blocker).
