# ATM Mapping

ATS reporting requirements: what the Wiser ATS Warehouse must store, and the field expectations behind Source-to-Hire (S2H) reporting.

Source: Data Brief Brief -> ATM Mapping tab.

## Function

- **Function:** Wiser's ATS Warehouse must store anonymised ATS reports via API, accounting for candidates' anonymised information, source of application, and stage status. The API report provides data updated on standard 15-minute caching cycles or once a day depending on ATS.
- **Expected fallback:** Manual uploads of data must be accepted by the warehouse where APIs are not available. A template upload should be provided.
- **Downstream function:** Source-to-Hire Recruitment Funnel AI Insights.

## Requirements

Column headers in source: REQUIRMENT / DATA / Data / EXPECTATION. Rendered here as Requirement / Item / Field / Expectation.

| Requirement | Item | Field | Expectation |
|---|---|---|---|
| Stage-by-stage conversion | Submission | DateTime | Naming conventions within each ATS provider differ. Data ingestion will require standardisation, e.g. Workday `Review` vs GreenHouse `Recruiter_Screen`. |
|  | Review | DateTime |  |
|  | Interview | DateTime |  |
|  | Offer | DateTime |  |
|  | Hire | DateTime |  |
|  | Rejection | DateTime |  |
| Latest stage per candidate | Always known status of each candidate, delivered via anonymised ID |  | Anonymisation of data is required. Ideally an anonymised code will be sent to the ATS with a careersite submission which we can retrieve. If blocked, the candidate ID will be attached to the data. |
| Time in stage | StageDateTime |  | Measures time to next stage. |
| Candidate location | City Name |  | Depends on job application form and questionnaire location. |
| Source attribution | Custom RAAS report will include source attribution | Source Medium URL | Only if set up with client; this data standardly aligns with GA4 and Adobe data. |
| Job / Requisition data | Job Title |  | Name of role. |
|  | JobFamily |  | Team structure. |
| Rejection stats | Typically a status mark in the ATS | Status to be defined |  |
| Rejection time | The date of the rejection | Rejection_datetime |  |
| Rejection reason | May or may not be available within the ATS depending on system set-up. |  |  |
