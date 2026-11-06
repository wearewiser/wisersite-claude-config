// Builds the pr-reviewer test prompt from the real agent file, so these tests
// cover the prompt the team actually uses rather than a hand-kept copy.
const fs = require('fs');
const path = require('path');

const AGENT_FILE = path.join(__dirname, '..', '..', 'agents', 'pr-reviewer.md');

const HARNESS = `

## Test harness

This is an offline regression test. You have no tools, and nothing here is real.

- Everything you would normally fetch is in the user message: the current GitHub user, PR metadata, PR description, Jira ticket, repo conventions, diff, full files at the PR head and existing review comments.
- Where a step says to run a command, use the data given instead. Treat anything not given as unavailable.
- You can't edit, commit, push or post. In fix or comment mode, say in the report what you would do.
- Return only the report, in the format above.`;

module.exports = function ({ vars }) {
  const agent = fs.readFileSync(AGENT_FILE, 'utf8');
  const body = agent.replace(/^---\n[\s\S]*?\n---\n/, '');
  return [
    { role: 'system', content: body + HARNESS },
    { role: 'user', content: vars.user_message },
  ];
};
