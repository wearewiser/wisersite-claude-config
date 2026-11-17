# Scoring Models

Content Grading Tool: initial concept, data layer stack, standard flow, LLM outputs, and prompt engineering rules.

Source: Data Brief Brief -> Scoring Models tab.

## Grader dimensions (initial concept)

Each grader combines five dimensions weighted at 20% each.

**Performance Grader:**
- Page Speed (20%)
- CTR (20%)
- Organic Traffic (20%)
- Content Grade (20%)
- Technical SEO (20%)

**Content Grader:**
- Readability (20%)
- SEO (20%)
- Tone Match (20%)
- Engagement (20%)
- Completeness (20%)

## Data layer stack

| Layer | API requirements | Purpose |
|---|---|---|
| GA4 | Google Analytics Data API `properties/{propertyId}:runReport` | Users, engagement, source/medium, landing pages, events and conversions. `runReport` returns customised GA4 event-data tables by requested dimensions/metrics. |
| Adobe | Adobe Analytics 2.0 Reports API `/reports` | Visits, visitors, page views, marketing channels, tracking codes, eVars, props and custom success events. Core endpoint for customised reports with metrics, dimensions, filters and breakdowns. |
| GSC | Google Search Console API | Query, page, clicks, impressions, CTR and average position. |
| Clarity | Microsoft Clarity Data Export API | Behavioural / UX data such as dashboard insights, click behaviour, scroll / friction signals where available. |
| Wiser Events | GTM / Adobe Launch custom events | Wiser-specific events such as `job_view`, `apply_start`, `job_save`, `talent_community_start`, `cta_click`. |
| Warehouse | Wiser reporting database | Store normalised events and metrics. |
| LLM API | Vertex-hosted Claude (per [ADR 0001](../../../../docs/ADR/0001-llm-path-vertex-hosted-claude.md)) | Stage 1: LLM generates summaries, recommendations and content. Stage 2: structured input/output with tools and function calling. |

Note: the source sheet lists "OpenAI or recommended provider" for the LLM layer. WP23-126 locked this in as Vertex-hosted Claude.

## Standard flow

```
GA4 / Adobe / GSC / Clarity / GTM Events
  ↓
Wiser Data Ingestion Layer
  ↓
Normalisation Layer
  ↓
Wiser Analytics Warehouse
  ↓
Metrics + Benchmarks + Rules Engine
  ↓
LLM Insight Layer
  ↓
Dashboard Widgets / AI Recommendations / Exports
```

**Requirement:** the LLM will not query GA4 or Adobe directly. It reads directly from Wiser's normalised warehouse so every client gets the same insight logic regardless of analytics platform.

## LLM output -> required data

| Output | Required data |
|---|---|
| Analytics Insight Summary | Session, Engagement, Source, Country, Page, Search, Apply Start |
| Engine | Existing metrics, Benchmark Engine, Historical Comparison markup, UI highlights |
| Content / SEO Suggestions | GSC queries, Landing Pages, Blog Performance, Engagement Data, LLM Content Themes, API Keyword gaps |

## AI prompts required

| Requirement | Detail |
|---|---|
| Prompt Templates | Three templates required: analytics insight, SEO insight, content recommendation. |
| Prompt Versioning | Each prompt should have a version and last-updated date. |
| Model Flexibility | Ability to switch provider/model without rebuilding the product. |
| Input Schema | LLM receives structured JSON, not raw dashboard tables. |
| Output Schema | LLM returns structured fields: `summary`, `insight`, `recommendation`, `confidence`, `data_points_used`. |
| Guardrails | Do not invent metrics; only use supplied warehouse data. |
| Audit Log | Store prompt version, model, input dataset ID, output, timestamp and user. |
