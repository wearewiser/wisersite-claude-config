---
status: Accepted
date: 2026-09-16
original-date: 2026-07-23
migrated-from: wisersite-data-api-layer/docs/ADR/0003-nestjs-api-framework.md
---

# 0003: NestJS for New Wiser Backend Services

## Context

Wiser's previous framework was TechJS, a custom framework built by a previous solutions architect. When that person left, there was no community or maintenance guarantee. A replacement was needed for all new backend services.

## Decision

Use NestJS for all new Wiser backend microservices. NestJS runs on Express under the hood and was chosen for its dependency injection model and the strength of its community.

## Consequences

- Consistent with the 19 existing ATS proxy microservices, which are also NestJS.
- New team members onboard without learning a proprietary framework.
- Express compatibility means existing Wiser patterns (Pino logging, health endpoints) apply directly.
- New backend services default to NestJS unless a specific reason is documented in a superseding ADR.
