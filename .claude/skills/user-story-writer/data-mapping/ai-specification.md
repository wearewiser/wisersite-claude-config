# AI Specification

Expected AI models required for content tooling.

Source: Data Brief Brief -> AI Specification tab.

| AI Feature | Model | Prompt Template | Inputs | Outputs | Human Review |
|---|---|---|---|---|---|
| Analytics Insights | GPT | Analytics Prompt V1 | Metrics | Recommendation | Required |
| Content Generation | GPT | Content Writer V1 | Brief | Content | Optional |
| SEO Recommendations | GPT | SEO Advisor V1 | SEO Scores | Recommendations | Required |

Note: the Model column lists "GPT" in the source sheet. WP23-126 landed on Vertex-hosted Claude as the LLM path (see [ADR 0001](../../../../docs/ADR/0001-llm-path-vertex-hosted-claude.md)). Treat "GPT" as a placeholder; use Claude when writing stories that reference an AI feature's model.
