---
status: Accepted
date: 2026-09-16
original-date: 2026-07-31
migrated-from: wisersite-data-api-layer/docs/ADR/0002-gcp-functions.md
---

# 0002: GCP Cloud Functions for ATS and Analytics Ingestion

## Context

Wiser needs to fetch initial data from third-party ATS and analytics services via API (SmartRecruiters, Adobe, MS Clarity, etc.). Each provider is a separate integration, and each client uses a different subset. Failure of one integration must not block others.

## Decision

Wiser uses GCP Cloud Run functions plus Cloud Scheduler, Parameter Manager, Secret Manager, and Google Cloud Storage for ATS and analytics ingestion. Ingestion functions live in `wisersite-data-fetching-gcp-functions`.

The pattern per integration:

1. Cloud Scheduler is set up to call a job per client per service. Each call is isolated, enabling simple retries without blocking any other call.
   - Example: client NEXT has two scheduled jobs; Adobe Analytics and SmartRecruiters ATS.
2. Each service has its own Cloud Run function and is called with the client name parameter. The client name is unique.
   - Route shape: `GET /analytics/<provider>/<client>/` (e.g. `/analytics/ga/next/`).
3. Each client has its own configuration in Parameter Manager (PM), with secrets held in Secret Manager. The key is the unique client name.
4. Typical flow when a function is called (example: NEXT client, SmartRecruiters ATS):
   1. Fetch the NEXT API key for SmartRecruiters from Parameter Manager (which resolves it via Secret Manager).
   2. Fetch the data via the provider's API.
   3. Convert the data to CSV.
   4. Send the CSV to Google Cloud Storage.
   5. (Out of scope of this ADR) The CSV is picked up downstream by BigQuery.
5. All functions live in a VPC so cross-service access permissions do not need explicit configuration per function.

Chosen for cost-effectiveness given functions fire once a day, and for tight integration with GCS/BigQuery (a downstream requirement).

## Consequences

- Ingestion scales per (client, provider) rather than per client alone.
- Failure of one client's provider integration is isolated from all others.
- Adding a new provider means: a new Cloud Run function, a Cloud Scheduler entry per client, and a Parameter Manager entry per client.
- Config lives in Parameter Manager (per-client), not in code.
