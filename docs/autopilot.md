<!--
Copyright 2026 Google LLC.
SPDX-License-Identifier: Apache-2.0
-->

# EGM Autopilot (Claude Code)

`/egm:egm-autopilot <JIRA-KEY> [--lane small|feature|high] [--resume] [--dry-run]`
takes an assigned Jira ticket to a reviewed Merge Request. It runs in your own
Claude Code session, with your own `glab` and Atlassian login. There is no bot.
The MR opens as a Draft in your name, and you review and merge it.

```
Jira -> [0 Intake] -> [1 Lane] -> [2 Worktree] -> [3 Spec] -> [4 Spec review] -> [5 Implement]
        park if weak                              self-interview   Goldfish        tests first
                                                                  (high: human spec gate)
     -> [6 Code review: Goldfish] -> [7 Draft MR + Jira comment]  -> YOU review
```

- **Lanes** (`skills/egm_autopilot/references/lanes.md`): risk sets the rigor.
  Auth, payments, schema, public API, CI/infra, security labels or a large blast
  radius force `high`, which adds a human spec gate.
- **Spec review** reuses `egm-review` (uninterrupted). **Code review** adds four
  stateless reviewers (`egm-code-spec-auditor`, `egm-code-bug-hunter`,
  `egm-test-adequacy`, `egm-code-security`) that see only the spec, a diff file
  and the sensor output.
- **Sensors** (build, lint, typecheck, tests, secret scan) are ground truth over
  model opinion. Configure them in the target repo's `egm-autopilot.config.yaml`.
- **Parking:** unanswerable questions go to Jira with recommended defaults and
  the label `ai-needs-input`. Resume with `--resume`.
- **Guard** (`.claude-plugin/hooks/guard.sh`, a PreToolUse hook on Bash): blocks
  force pushes, pushes to protected branches, `glab mr merge|approve`, hook
  bypass, and commits without `Co-Authored-By: Claude <model> <noreply@anthropic.com>`.
  It is defense in depth. Protected branches on the server are the real control.
- Jira content is untrusted input. Run state lives in `.egm/runs/<KEY>/`.

Requires `jq`, `glab` (logged in) and the Atlassian MCP connector.
