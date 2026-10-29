# MR description

The MR is reviewed by people on the team, so it follows the **repo's own merge request
template** when the repo has one. The EGM review is added as one clearly labelled block. It
never replaces or reorders the repo's sections.

Title: `<KEY>: <ticket summary>`. Stacked MRs: `<KEY> [n/N]: <what this unit delivers>`, or
`<KEY> [<repo> n/N]: ...` across repos. Prefix `[SPEC]` for spec-gate MRs. Use `Draft:` when
attention is needed. Use the repo's title convention if it documents one.

## 1. Resolve the template (per repo, Phase 7)

Look in `<repo>/.gitlab/merge_request_templates/` (GitLab matches names case-insensitively):

| Found | Use |
|---|---|
| no folder, or no `.md` files | the fallback in section 4 |
| one file (`Default.md` or `DEFAULT.md`) | that file |
| several files | pick by ticket type: a bug, or a `bugfix` label, takes `bugfix.md`; a `hotfix` label, or a Blocker or Highest priority incident, takes `hotfix.md`; otherwise the default. If the choice is unclear, use the default and say which one you chose in the EGM block |

Known repos (as of Oct 2026): `ai-nexus`, `socket-chat`, `socket-chat-admin`, and
`ai-chatbot-widget` ship templates. `ai-nexus-client` and `ai-labs-test` do not and use the
fallback. Re-check the folder at Phase 7. Do not rely on this list.

## 2. Fill the repo template

- **Keep every heading, its order and its checkbox wording.** Do not rename, reorder or delete
  sections.
- **Tick a box only when this run verified it and saw the result.** For checks the run cannot
  perform (manual testing, "verified with the widget connected", monitors, release
  coordination), leave the box unticked and write `(not verified by EGM: <what a human must do>)`
  after it.
- **Replace placeholders:**
  - `<ISSUE_ID>`, `<MR_ID>`: the Jira key, and the related MR if one exists, else remove the line.
  - `[Step 1]`, `[Step 2]`: the steps actually run, or `N/A`.
  - `%{all_commits}`: a bullet per commit on this branch, from `git log --format='- %s' <base>..HEAD`.
    GitLab only expands this placeholder in its own UI, so write the list yourself.
  - `[SCREENSHOT_DESCRIPTION]` and its image: remove the Attachments block if there are none.
- **Remove the template's HTML comments** (`<!-- ... -->`) once their section is filled.
- **Unknown facts** (deployment dates, rollback time, environments): write
  `unknown: developer to fill`. Never guess.
- **Sections that do not apply:** keep them and write `N/A: <reason>`. Delete a section only
  when the template itself marks it optional.
- **Map what the run knows onto the repo's sections:**
  - Related issues: the Jira link.
  - What the MR does: tick the type that matches the unit (Feature, Enhancement, Refactor, Bugfix).
  - Why: the ticket's purpose, in the ticket's words, cited.
  - Notes and Considerations: tick only the flags that are true (for example "Requires
    environment variable changes" if the spec's config changes say so).
  - Tech Notes: Open Decisions and Assumptions go here.
  - Consumer or contract sections (for example `socket-chat`'s Contract & Consumer Impact):
    fill from the spec's Contract section. Name the other repos' MRs when they exist.
- **Do not edit the repo's own wording** beyond placeholders, even if it looks wrong.

## 3. Append the EGM review block

Always the last section, after the repo's content. Put a one-line callout above the repo's
first section only when there are open decisions:
`> EGM: N decision(s) need your judgment. See "EGM Autopilot review" at the bottom.`

```markdown
## EGM Autopilot review

### Needs your judgment  <!-- omit if empty -->
- **Open Decisions** (I chose a default and proceeded; veto if wrong)
  1. <decision> -> chose **<default>** because <reason>. Alternatives: <a>, <b>.
- **Spec Deviations**: <what changed vs the approved spec, why, evidence>
- **Unresolved findings**: <finding, severity, why not fixed>

### Series or related MRs  <!-- omit if single-repo, single-unit -->
- Stacked: part <n> of <N>. Merge in order; each MR targets the one before it.
- Multi-repo: merge order <repo A> -> <repo B>. Do not merge a consumer before its producer.
  - <repo>: <MR link> (<what it delivers>)

### Answers I acted on  <!-- omit if the run never parked -->
- Q1 <question>: you chose **B** (<option>) | defaulted to **A** (no answer)

### Acceptance-criteria traceability
| # | Acceptance criterion | Spec § | Test(s) | Code |
|---|---|---|---|---|
| 1 | ... | §3.2 | `test_x` | `path/file.py:L10-40` |

### Assumptions (low impact, recorded not asked)
- ...

### Verification (checks run in this session)
| Check | Result |
|---|---|
| Build / Lint / Typecheck | pass / fail / not configured |
| Tests (new / total) | 12 new / 340 pass |
| Secret scan | clean / skipped (tool missing) |
| Baseline failures (pre-existing) | none, or list them |

### AI review (isolated reviewers)
Rounds: spec <n>, code <n>. Findings: <applied> applied, <decided> decided, <deferred> deferred,
<rejected> rejected (no evidence). Reviewers: egm-code-spec-auditor, egm-code-bug-hunter,
egm-test-adequacy[, egm-code-security].

### Follow-ups (out of scope, not implemented)
- <suggested Jira sub-task title and one-line description>

---
Lane: `<small|feature|high>` | Template: `<file used>` | Confidence: **<high|medium|low>** (<reasons>)
Run: `<run-id>` | Audit trail: `<run-dir>/`
Generated by egm-autopilot.
```

## 4. Fallback layout (repos with no template)

Use these sections, then the EGM block from section 3.

```markdown
## Summary
<2-4 sentences: what changed and why. Jira: <URL>. Spec: <path or link>.>

## Changes
- <one line per unit or commit group, with file references>

## Notes & considerations
- [ ] Requires DB migration (N/A if none)
- [ ] Requires environment variable changes
- [ ] Introduces breaking changes (name the consumers)
- [ ] Adds new dependencies (name them)

## Verification
<the EGM sensor table from section 3>
```

## Rules

- Never claim a check passed unless this run ran it and saw the result.
- Quote real file:line references. Do not invent them.
- Keep the whole description under about 150 lines, excluding attachments. Link the spec
  instead of pasting it.
- The EGM block is always present, even when the repo template has no matching section.
