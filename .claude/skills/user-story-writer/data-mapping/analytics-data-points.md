# Analytics Data Points

Candidate behaviour data. Each field maps a Wiser reporting concept to its GA4 and Adobe equivalents, with custom naming conventions where applicable.

Source: Data Brief Brief -> Analytics Data Points tab.

Reference API docs mentioned in the source:
- GA4 Data API
- Adobe Analytics Reporting API
- Google Search Console API
- Microsoft Clarity API

The source's "Data Model Classification" column is `NA` for every populated row and has been omitted.

## Behaviour Tracking

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Click Count | Measure the total volume of tracked click interactions across the site and identify engagement with key interactive elements. | Custom GTM Event | Custom Event |  |  |
| CTA Click Rate | Measure the percentage of sessions resulting in a CTA interaction and evaluate CTA effectiveness. |  |  |  |  |
| Dead Clicks | Volume of users hitting a dead click. | Clarity | Clarity | Dead Click Count |  |
| Element Clicks | Component tracking to be rolled out as custom events. | Custom GTM Event | Custom Event | Component_XX |  |
| Excessive Scrolling | Identify sessions where users scroll significantly more than expected, potentially indicating difficulty locating content or navigation issues. | Clarity | Clarity | Excessive Scroll |  |
| Exit Rate | Identify page exit volumes. | exits | exits |  |  |
| Heatmap Clicks | Clicks of users across the site. | Clarity | Clarity | Not in scope |  |
| Heatmap Interactions | Visualise aggregate user interactions including clicks, scrolling and engagement hotspots across page content. | Clarity | Clarity | Not in scope |  |
| Quick Backs | Identify pages where users rapidly return to the previous page, indicating potential content mismatch or poor user experience. | Clarity | Clarity | Quickback Click |  |
| Rage Clicks | Volume of users clicking a non-clickable area. | Clarity | Clarity | Rage Click Count |  |
| Scroll Completion Rate | Identify the completion rate of each scroll. | Clarity | Clarity | Scroll Depth |  |
| Scroll Depth | Identify the average length of the page a user scrolls down. | scroll_depth_100 / sessions | Custom Events | scroll_depth_25, scroll_depth_50, scroll_depth_75, scroll_depth_100 |  |
| Session Recordings | Review individual user journeys and understand how users navigate, scroll, click and interact with site content. | Clarity | Clarity | Not available from API |  |
| User Frustration Signals | Identify sessions containing frustration indicators such as rage clicks, dead clicks, excessive scrolling and quick backs. | Clarity | Clarity | Not available from API |  |

## Blog Performance

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Average Engagement Time (Blog) | Total engagement duration per blog. | pagePath + userEngagementDuration | pageURL + timeSpentPerVisit |  |  |
| Blog Page | Categorisation of a page path to blogs. | pagePath | pageURL |  |  |
| Engagement Rate | Total engagement rate per blog. | pagepath=blog + engagementRate | Calculated |  |  |
| Engaged Sessions | Total engaged sessions across blogs. | pagepath=blog + engagedSessions | Calculated |  |  |
| Source | Source which blog visitors derived from. | sessionSource | Marketing Channel / Referrer |  |  |

## Content Performance

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Average Engagement Time | Total average engagement time for users. | userEngagementDuration | timeSpentPerVisit |  |  |
| Engaged Sessions | Total number of visitors in an engaged session on the page. | engagedSessions | Calculated |  |  |
| Page Sessions | Total number of visitors to a specific page. | pagePath + Sessions | pageURL + visits |  |  |
| Page Title | Name the page URLs. | pageTitle | pageName |  |  |
| Page URL | Define the pages against visitor number. Standardisation will be required (with others being grouped), and blog and job descriptions requiring separation. | pagePath | pageURL |  |  |

## Conversion Events (Non-ATS)

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Apply Start | Custom event. | apply_start | Custom | apply_start |  |
| Apply Start Rate |  | apply_start / Session | Custom | apply_start / Session |  |
| Click to Social | Social clicks custom events. | Social_click | Custom | social_click |  |
| Job Save |  | job_save | Custom | job_save |  |
| Job Search |  | search_job | Custom | search_job |  |
| Job View |  | job_view | Custom | job_view |  |

## Device Usage

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Desktop Engagement Rate |  | deviceCategory=desktop + engagementRate | deviceType=desktop + calculated metric |  |  |
| Desktop Session |  | deviceCategory=desktop + sessions | deviceType=desktop + visits |  |  |
| Device Category | Define device types against session totals. | deviceCategory | deviceType |  |  |
| Mobile Engagement Rate |  | deviceCategory=mobile + engagementRate | deviceType=mobile + calculated metric |  |  |
| Mobile Sessions |  | deviceCategory=mobile + sessions | deviceType=mobile + visits |  |  |
| Other Session |  | deviceCategory=other | deviceType=other |  |  |
| SmartTV Sessions |  | deviceCategory=smarttv | Implementation Dependent |  |  |
| Tablet Sessions |  | deviceCategory=tablet + sessions | deviceType=tablet + visits |  |  |
| Tablet Engagement Rate |  | deviceCategory=tablet + engagementRate | deviceType=tablet + calculated metric |  |  |

## Job Discovery

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Job Apply Click | Total volume of candidates who go through to the ATS. Important for clients that do not have integrated job application forms on site. | apply_start | Success Event |  |  |
| Job Detail Views | Total volume of candidates who stayed on a job description page. | pagePath contains /jobs/ OR custom job_view | Custom Event |  |  |
| Job Save | Total volume of candidates who saved a job. | job_save | Custom Event | job_save |  |
| Job Save Rate | Saved-jobs rate. | job_save / sessions | Calculated |  |  |
| Job View Clicks | Total volume of users who click through to a job description from the Job listing page. | job_view | Custom Event |  |  |
| Job View Rate | Total views of session. | job_view / sessions | Calculated |  |  |

## Landing Page Data

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Apply Start Rates | Average apply start rate. | Calculated | Calculated |  |  |
| Engagement Rates | Engagement rates of visitors on a landing page. | engagementRate | Calculated |  |  |
| Engagement Sessions | Total volume of engaged sessions on a landing page. | engagedSessions | Calculated |  |  |
| Landing Page | Top pages for visitors. | landingPage | entryPage |  |  |
| New Users | Total number of new users on a specific landing page. | newUsers | newVisitors |  |  |
| Session | Total session number across landing pages. | sessions | visits |  |  |

## Location

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| City Engaged Sessions | Average engagement sessions by city. | city + engagedSessions | city + engaged visits (calculated) |  |  |
| City Engagement Rate | Cities' engagement rates. | city + engagementRate | city + calculated metric |  |  |
| City Sessions | Total sessions against city. | city + sessions | city + visits |  |  |
| Country Apply Start Rate | User apply-start rate by country. | country + apply_start / sessions | country + calculated metric |  |  |
| Country Apply Starts | User starts per country. | country + apply_start | country + custom success event |  |  |
| Country Engaged Sessions | Average engagement rate by country. | country + engagementRate | country + engaged visits (calculated) |  |  |
| Country Engagement Rate | Average country engagement rate. | country + engagementRate | country + calculated metric |  |  |
| Country Sessions | Total sessions against country. | country + sessions | country + visits |  |  |

## Overview

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Average Session Duration | Total session duration. | averageSessionDuration | averageTimeSpentPerSession |  |  |
| Bounce Rate Average | Global site bounce pages. | bounceRate | bounceRate |  |  |
| Engagement Rate | Average engagement rate. | engagementRate | calculated metrics |  |  |
| Pages Per Session | Total session per page. | screenPageViews / sessions (calculated) | pageViews / visits (calculated) |  |  |

## Search Behaviour

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Hero Job Search | Job discovery job search interaction across the job listing page. | Custom Event: hero_job_search | Custom Event | hero_job_search |  |
| Job Searches | Total number of job searches across the site. | Total Job Searches | search | job_search |  |
| Navbar Job Searches | Interactions with the NavBar searches by term. | Custom Event: navbar_job_search | Custom Event | navbar_job_search |  |
| Search Country | Country filters selected by users. | country + search | country + internal search |  |  |
| Search Term Session | How many sessions contain a search interaction and the relationship between search usage and engagement/conversion behaviour. | searchTerm + sessions | internal search keyword + visits |  |  |
| Search Terms | Search terms input in the open search function. | searchTerm | Internal Search Keyword |  |  |
| Search Volume | Total number of searches input by users. | search event count | internal search count |  |  |

## SEO and Search

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Average Position | Monitor average search-engine ranking position for tracked keywords and landing pages. | GSC | NA |  |  |
| Click Through Rate |  | cta_click / sessions | Custom Success Event |  |  |
| Clicks | Volume of clicks generated from organic search listings. | GSC | NA |  |  |
| Landing Page SEO Session | Landing pages that generate the highest volume of organic search traffic. | GSC + GAJoin | NA |  |  |
| Organic Impressions | How frequently pages appear in organic search results. | GSC | NA |  |  |
| Organic Session | Volume of sessions originating from organic search channels. | GA4 + GSC | NA |  |  |
| Organic Users | Number of unique users arriving via organic search. | GA4 + GSC | NA |  |  |
| Search Query | Search terms generating visibility and traffic from search engines. | GSC | NA |  |  |
| Search Query Sessions | Connect organic search queries to on-site sessions and engagement outcomes. | GSC | NA |  |  |

## Session

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Average Session Duration | Average session duration from all visitors. | averageSessionDuration | averageTimeSpentPerSession |  |  |
| Bounce Rate | Total user bounce rates. | bounceRate | bounceRate |  |  |
| Engaged Sessions | Total engaged sessions. | engagedSessions | calculated engaged visits |  |  |
| Engagement Rate | Total engagement rate across all visits. | engagementRate | calculated metric |  |  |
| Events | Requires all event tracking to be pulled into warehouse. | eventCount | eventCount |  |  |
| Pages Per Session | Total pages per session. | screenPageViews / sessions | pageViews / visits |  |  |
| Session Conversion Rate | Session conversion rate. | sessionConversionRate (or calculated) | calculated metric |  |  |
| Sessions | Total session volume of visitors. | Session | visit |  |  |

## Source Performance

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Apply Start Rate | Application-start conversion rate. | apply_start / sessions | Custom Calculated Metric |  |  |
| Apply Starts | Application starts. | apply_start (custom event) | Custom Success Event |  |  |
| Campaigns | Pre-set campaign information against sessions. | sessionCampaignName | Tracking Code (s.campaign) |  |  |
| Engagement Rate | Users' engagement rate. | engagementRate | Calculated |  |  |
| Engagement Sessions | Users' total engaged sessions. | engagedSessions | Calculated |  |  |
| Medium | Medium channel attached to the source of the user. | sessionMedium | Marketing Channel / eVar |  |  |
| Source | Where users came from. | sessionSource | Marketing Channel / Referrer / eVar |  |  |
| Source / Medium | Pre-set source and medium sets for client. | sessionSourceMedium | Marketing Channel |  |  |

## Talent Community

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| Talent Community Conversion Rate | Total conversion rate from candidates submitting a form. | talent_community_start | Calculated |  | Not in scope |
| Talent Community Rate | Conversion rate of candidates to talent pools. | talent_community_start / sessions | Calculated |  | Not in scope |
| Talent Community Start | Total number of candidates that engage with talent community banners. | talent_community_start | Custom Event | talent_community_start | Not in scope |
| Talent Community Submit | Total volume of candidates who submit a talent pool request. | talent_community_submit | Custom Event | talent_community_submit | Not in scope |

## Users

| Field | Rationale | GA4 | Adobe | Custom Naming | Notes |
|---|---|---|---|---|---|
| New Users | Total volume of new visitors. | newUsers | newVisitors |  |  |
| Total Users | Total site visitors. | activeUsers | uniqueVisitors |  |  |
