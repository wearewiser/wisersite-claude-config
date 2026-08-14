# Agent Regression Tests

PromptFoo test suite for the Wiser Claude agents. Catches quality drift when agent prompts change or the underlying model is updated.

Runs automatically on any push or pull request that modifies a file in `agents/`.

## Tests

1. Ticket with no AC returns NOT READY - dor-guardian
2. Ticket with AI features but no AI behaviour defined returns NOT READY - dor-guardian
3. Output always contains the required table and verdict format - dor-guardian
4. Fully defined ticket returns READY TO START - dor-guardian
5. UI ticket with no designs returns NOT READY - dor-guardian
6. Complex ticket with no spike completed returns NOT READY - dor-guardian
7. Non-UI ticket correctly marks Design as N/A - dor-guardian
8. Uncommitted changes causes Development Complete to FAIL - dod-guardian
9. Clean state with passing checks returns DONE or PENDING MANUAL CHECKS - dod-guardian
10. Output always contains the required structure - dod-guardian
11. Failing tests returns NOT DONE - dod-guardian
12. Being on main branch returns NOT DONE - dod-guardian
13. Failing linter returns NOT DONE - dod-guardian
14. AC not fully addressed returns NOT DONE - dod-guardian
15. Feature branch for a ticket includes correct prefix and ticket number - branch-guardian
16. Chore branch requires no ticket - branch-guardian
17. Feature branch with no ticket prompts for one - branch-guardian
18. Fix branch for a ticket includes correct prefix and ticket number - branch-guardian
19. Already on a valid feature branch proceeds without creating a new one - branch-guardian
20. Working on main is blocked - branch-guardian

## Running locally

Add your Anthropic API key to a `.env` file at the root of this repo:

```
ANTHROPIC_API_KEY=sk-ant-...
```

Then run:

```bash
npm run test:agents
```

Or run a single agent suite:

```bash
npx promptfoo eval --config promptfoo/dor-guardian.yaml --env-file .env
npx promptfoo eval --config promptfoo/dod-guardian.yaml --env-file .env
npx promptfoo eval --config promptfoo/branch-guardian.yaml --env-file .env
```
