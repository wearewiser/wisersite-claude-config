---
status: Accepted
date: 2026-09-16
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
- **Jade**: in-thread for governance visibility; formal approval pass runs via ticket #2 in the WP23-126 follow-up list.
- **Ian**: away; no blocker (Stephen has covered the technical view).

## Decision

**Option A - Vertex-hosted Claude, `europe-west1` or EU multi-region.**

- Auth: GCP IAM with per-service-account access (no long-lived Anthropic API key).
- Region: `europe-west1` if Claude is available there at build time; EU multi-region endpoint otherwise (GA May 2026 per assessment doc). Validated by WP23-126 follow-up ticket #18.
- Model: latest available Claude via Vertex at time of build (Sonnet-tier for MVP unless quality gap forces Opus). To be validated per-feature in the shared `AIProvider` layer (WP23-126 follow-up ticket #4).

## Consequences

- **WP23-175 and WP23-304 re-scope.** WP23-304 changes from "Anthropic direct spike" to "Vertex-hosted Claude spike" (endpoint + IAM instead of API key). WP23-126 follow-up ticket #19 owns the re-scope; ticket #18 owns the availability/latency validation in `europe-west1`.
- **Governance pass required.** Vertex-hosted Claude runs through Jade's AI-tools approval process before it can be used in production. WP23-126 follow-up ticket #2 owns this.
- **~2-3 wks Vertex ramp cost.** The first AI feature bears the cost of GCP service account setup, Vertex quota requests, endpoint config, plus team ramp on the Vertex SDK. Realistic time-to-first-shipped-feature: ~4-5 weeks total.
- **Tenant isolation lever.** IAM per service account replaces prompt / cache-key discipline as the primary isolation surface. The existing `getTenantDataSource` pattern in the plugin (per-tenant Postgres) remains the tenant-scoped data access mechanism.
- **All AI orchestration lives in the plugin.** Following the widget pattern (self-contained module inside `wisersite-and-payload-plugin`), calling the shared `AIProvider` interface built in follow-up ticket #4. No new microservice per AI feature.
- **Cost visibility via GCP billing.** No separate Anthropic dashboard to reconcile. AI-specific log-based metrics (token count, cost per tenant, cache hit/miss, validation failure rate) still needed - WP23-126 follow-up ticket #8.
- **Model version cadence lags Anthropic direct by days-to-weeks.** Rarely load-bearing, but flagged in case a specific new-Claude feature is time-sensitive.
- **Alt-text microservice (OpenAI) is unchanged by this decision.** Product-facing AI features use Vertex-hosted Claude; the alt-text microservice remains on OpenAI unless separately reassessed.

## Related

- WP23-126 (this assessment).
- WP23-175 (first product-facing AI feature; owns re-scope consumption).
- WP23-304 (spike; owns endpoint + IAM re-scope, ticket #19).
- WP23-7 (Named AI Service Owner; hard governance blocker, ticket #1).
- Ticket #2 (Jade governance pass for Vertex-hosted Claude).
- Ticket #4 (shared `AIProvider` interface + Vertex-hosted Claude implementation).
- Ticket #18 (Vertex Claude availability + latency validation in `europe-west1`).
- Ticket #19 (WP23-304 re-scope for Vertex endpoint + IAM).
