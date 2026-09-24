# Data Brief Brief

Static copy of the Wiser data brief tabs. The user-story-writer skill consults these files when checking that a story's Technical notes / Data bullet aligns with real fields, ownership, and rules.

Source: Google Drive -> Discovery Phase -> "WiserSite | Data Brief Brief" spreadsheet.
Last synced: 2026-09-23.

## Files

| File | Covers | Consult when |
|---|---|---|
| [system-architecture.md](system-architecture.md) | Data sources feeding the warehouse, their purpose, ETL flow, storage, ownership | Story touches an ingestion source (GA4, GSC, ATS, CMS, Adobe, SEMRush, Clarity) or asks who owns a piece of data |
| [atm-mapping.md](atm-mapping.md) | ATS reporting requirements: stages, timestamps, candidate, source, job, rejection fields | Story is about the Source-to-Hire funnel or hiring data |
| [s2h-and-hire-funnel-data.md](s2h-and-hire-funnel-data.md) | Wiser event names mapped to GA4 and Adobe equivalents; standard source-category dictionary | Story defines or references a Wiser event or attribution source |
| [analytics-data-points.md](analytics-data-points.md) | Candidate behaviour metrics with GA4 / Adobe mapping and custom naming conventions | Story defines KPIs, dashboard fields, or reporting widgets |
| [ai-specification.md](ai-specification.md) | AI feature -> model / prompt template / inputs / outputs / human review requirement | Story defines an AI feature or a prompt-driven output |
| [scoring-models.md](scoring-models.md) | Content / performance grader weights, data layer stack, standard flow, LLM output requirements, prompt engineering rules | Story defines a scoring model, an LLM output, or prompt behaviour |

## Notes on this copy

- The sheet is the true source of truth. If content diverges materially from these files, re-sync.
- Obvious source typos have been corrected here for LLM readability (e.g. "annomysed" -> "anonymised", "Requirments" -> "Requirements", "Volumne" -> "Volume", "Sponspored" -> "Sponsored"). Semantics and field names are preserved verbatim.
- Where the source references an LLM provider as "GPT" or "OpenAI or recommended provider", these files note that WP23-126 landed on Vertex-hosted Claude (see [ADR 0001](https://github.com/wearewiser/wisersite-claude-config/blob/develop/docs/ADR/0001-llm-path-vertex-hosted-claude.md)).
- Blank cells in the source mean the mapping is undecided. Treat those as Open Questions in stories, not gaps to fill.
- Some source rows are mid-edit (e.g. the Microsoft Clarity row in System Architecture). These are rendered faithfully so re-syncs are easy to diff.
