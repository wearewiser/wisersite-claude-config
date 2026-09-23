# System Architecture

Base-level documentation of data sources feeding the Wiser data warehouse.

Source: Data Brief Brief -> System Architecture tab.

| System | Expectations | Purpose | Data Flow | Storage | Final Owner |
|---|---|---|---|---|---|
| GA4 | Google Analytics and Google Tag Manager raw data | Website Analytics | API -> ETL -> Reporting Layer | Warehouse | Wiser |
| GSC |  | Search Metrics | API -> ETL -> Reporting Layer | Warehouse | Wiser |
| Application Tracking System | Primary ATS providers Workday, Oracle, SmartRecruiters, GreenHouse and Phenom | Hiring Data | API -> ATS Mapping Layer | Warehouse | Client |
| CMS | Website and system performance data | Content Data | API | Warehouse | Client |
| SEMRush / DataForSEO |  | SEO Data | API | Warehouse | Wiser |
| Adobe Analytics 2.0 feed | Raw data from Adobe | Website Analytics | API -> ETL -> Reporting Layer | Warehouse | Wiser |
| Microsoft Clarity API |  | `POST https://www.clarity.ms/export-data/api/v1/project-live-insights` | `Authorization: Bearer <API_TOKEN>` |  |  |

Note on the Microsoft Clarity row: the source sheet has this row partially populated with the API endpoint and auth header in place of the standard columns. Rendered here as-is; treat purpose/storage/owner as Open Questions until the sheet is completed.
