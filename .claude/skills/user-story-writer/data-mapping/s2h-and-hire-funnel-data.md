# S2H and Hire Funnel Data

ATS standardisation requirements and analytics data required for Source-to-Hire mapping and hire funnel functions.

Source: Data Brief Brief -> S2H and Hire Funnel Data tab.

## Wiser event -> GA4 / Adobe mapping

Event and attribution field mapping across Wiser -> GA4 -> Adobe.

| Wiser Event | GA4 | Adobe |
|---|---|---|
| page_view | page_view | pageView |
| job_view | view_item / custom job_view | Custom Event |
| search_job | search | Internal Search Event |
| filter_job | custom event | Custom Event |
| apply_start | generate_lead / apply_start | Success Event |
| apply_complete | application_complete | Success Event |
| application_review | ATS | ATS |
| interview_stage | ATS | ATS |
| offer_stage | ATS | ATS |
| hire_stage | ATS | ATS |
| reject_stage | ATS | ATS |
| withdraw_stage | ATS | ATS |
| Source | sessionSource | Referrer Domain / eVar |
| Medium | sessionMedium | Marketing Channel / eVar |
| Campaign | sessionCampaignName | Tracking Code |
| Referrer | pageReferrer | Referrer |
| Landing Page | landingPage | Entry Page |
| UTM Source | utm_source | Custom eVar |
| UTM Medium | utm_medium | Custom eVar |
| UTM Campaign | utm_campaign | Tracking Code or eVar |
| UTM Content | utm_content | Custom eVar |
| UTM Term | utm_term | Custom eVar |

## Source Category Dictionary

Standard source-category buckets used to classify traffic origin.

| Wiser Field | Types |
|---|---|
| Job Boards | Indeed / Total Jobs / CV Library / Reed / Monster / LinkedIn Jobs |
| Organic Search | Google Organic / Bing Organic |
| Paid Search | Google Ads, Bing Ads |
| Social | LinkedIn Organic / Facebook Organic / Instagram Organic / TikTok Organic |
| Referral | Employee referral / Internal referral |
| Direct | Direct Traffic |
| Paid Social | LinkedIn Sponsored Jobs / LinkedIn Ads / Facebook Ads |
| Email | Email campaigns / CRM Campaigns |
| Other | Standard tools will absorb unknowns which will need to be mapped to field `unknown`. |
