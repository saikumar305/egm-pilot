<!--
Copyright 2026 Google LLC.
SPDX-License-Identifier: Apache-2.0
-->

# EGM Autopilot: how to use it

EGM Autopilot takes an assigned Jira ticket to a reviewed Merge Request. It runs in your own
Claude Code session with your own `glab` and Atlassian logins. There is no bot account. The MR
opens as a **Draft in your name**, and you review and merge it. You are the only mandatory
human step.

For the visual walkthrough, open `docs/autopilot-flow.html` in a browser.

## Contents

1. [Quick start](#1-quick-start)
2. [Prerequisites](#2-prerequisites)
3. [One-time setup: `/egm:egm-init`](#3-one-time-setup-egmegm-init)
4. [Running a ticket](#4-running-a-ticket)
5. [Every option](#5-every-option)
6. [What happens in a run](#6-what-happens-in-a-run)
7. [Features in depth](#7-features-in-depth)
8. [Multi-repo tickets](#8-multi-repo-tickets)
9. [Product umbrellas](#9-product-umbrellas)
10. [Parking, answering, and resuming](#10-parking-answering-and-resuming)
11. [Handing off to another session or person](#11-handing-off-to-another-session-or-person)
12. [Configuration reference](#12-configuration-reference)
13. [Safety rules and guardrails](#13-safety-rules-and-guardrails)
14. [Where things are stored](#14-where-things-are-stored)
15. [Troubleshooting](#15-troubleshooting)
16. [Limits and status](#16-limits-and-status)

---

## 1. Quick start

```text
# from inside the repo the ticket is about (or from your product umbrella)
/egm:egm-init                        # once per machine: create ~/.egm and register your repos
/egm:egm-autopilot LABS-2345 --dry-run   # plan only: no push, no MR, no Jira writes
/egm:egm-autopilot LABS-2345         # the real run
```

Start with `--dry-run` on every new ticket type. Read the plan, the spec and the lane choice,
then run it for real.

---

## 2. Prerequisites

| Need | Why | Check |
|---|---|---|
| Claude Code 2.1.271 or later | isolated reviewers need `omitClaudeMd` | `claude --version` |
| The `egm` plugin installed and enabled | provides the skills, agents and hooks | `claude plugin validate` |
| `git` | worktrees, branches, diffs | `git --version` |
| `jq` | guard hook and the workspace helper | `jq --version` |
| `glab`, logged in as you | opens MRs as you | `glab auth status` |
| Atlassian connector in Claude Code | reads and comments on Jira tickets | `/mcp` shows it connected |
| Your repos cloned locally | the run changes local checkouts | paths in `~/.egm/workspace.yaml` |

If `glab` cannot detect the GitLab host from a remote, set `GITLAB_HOST=gitlab.com` or create
the MR through `glab api`. The skill does this automatically when needed.

---

## 3. One-time setup: `/egm:egm-init`

`/egm:egm-init` builds your **per-user workspace**: a registry of your repos plus a short
knowledge file for each one. The autopilot reads this before it starts, so it knows your
repos from the first minute rather than searching blind.

```text
/egm:egm-init                          # create ~/.egm; offers to add the current repo
/egm:egm-init add ~/storable/ai-nexus  # register one repo (role inferred, you confirm)
/egm:egm-init add-umbrella ~/storable/aidlc-umbrella   # register every repo of an umbrella
/egm:egm-init refresh --all            # rebuild knowledge for repos that changed
/egm:egm-init status                   # repos, freshness, number of runs
/egm:egm-init remove old-repo          # unregister (asks first; never touches the repo)
```

### What it builds, per repo

- `overview.md`: what the repo is, its layout, how to build, test and lint it (with the file
  each command came from), conventions and entry points.
- `contracts.md`: what it **exposes** (HTTP routes, events, schemas, libraries) and what it
  **consumes**.
- `meta.json`: the commit the knowledge was built from. This drives the freshness check.

Plus a cross-repo `map.md` (who exposes and who consumes each contract, with evidence paths)
and `learnings.md` (categories of past parks and findings, never ticket text).

### Trust rules for the knowledge

- It is **context, not truth**. If it disagrees with the code, the code wins and the entry is
  flagged.
- It is built only from the repos. Never from ticket text, so one ticket cannot leak into
  another run.
- It never records secrets. Every claim cites a path, and unknowns are written as `unknown`.
- It is read by the main session only. Reviewers get a knowledge file only when a brief names
  that exact path.

### Freshness

Each repo's knowledge records the commit it was built from. The status shows one of:

| Status | Meaning | What the autopilot does |
|---|---|---|
| `fresh` | built from the current commit | uses it |
| `stale (n commits)` | the repo has moved on | refreshes just that repo first, or continues and says so |
| `unbuilt` | never built | builds it, or continues without it and says so |
| `missing` | checkout path no longer exists | reports it; you decide whether to remove it |

### Permission rules (recommended)

Without these, Claude prompts you every time it reads the workspace. `egm-init` will not edit
your settings; add them yourself (or run `/update-config`):

```text
Read(~/.egm/**)
Grep(~/.egm/**)
Glob(~/.egm/**)
```

Set `EGM_HOME` to move the workspace somewhere else (for example a shared location). The
default is `~/.egm`.

---

## 4. Running a ticket

```text
/egm:egm-autopilot <JIRA-KEY or Jira URL> [options]
```

Examples:

```text
/egm:egm-autopilot LABS-2345
/egm:egm-autopilot https://sparefoot.atlassian.net/browse/LABS-2345
/egm:egm-autopilot LABS-2345 --dry-run
/egm:egm-autopilot LABS-2345 --lane feature --base feature/pricing-api
/egm:egm-autopilot LABS-2345 --repos ai-nexus,nexus-client,admin-portal
/egm:egm-autopilot LABS-2345 --primary-only
/egm:egm-autopilot LABS-2345 --resume
```

Run it from the primary repo, or from your umbrella root. In an umbrella the primary repo is
chosen from the ticket.

---

## 5. Every option

| Option | What it does | Notes |
|---|---|---|
| `<JIRA-KEY or URL>` | the ticket to work on | required |
| `--dry-run` | runs intake, triage, repo scope, workspace planning and the spec review, then prints the plan and stops | no push, no MR, no Jira writes, no commits. The repo-scope prompt still runs |
| `--lane small\|feature\|high` | chooses the rigor level | can only **lower** the lane, and only if no hard-trigger fired. Hard-triggers always force `high` |
| `--base <branch>` | the branch to build on and target for the primary repo | use it when the ticket depends on unmerged work, such as another open MR's branch. Other repos use their default branch |
| `--repos a,b` | the exact registry repos to change, plus the primary | skips the multi-repo question |
| `--primary-only` | change only the primary repo | skips the multi-repo question; other candidates become follow-ups |
| `--resume` | continues a parked run from where it stopped | reads answers from the questions file and Jira comments |

The same options are accepted by the skill. `--resume` also works from any directory because
run state lives in `~/.egm/runs/<KEY>`.

---

## 6. What happens in a run

```text
Jira ticket
  -> 0 Intake          fetch the ticket, load repo knowledge, readiness score, park if weak
  -> 1 Triage          pick a lane: small | feature | high (risk sets the rigor)
  -> 1b Repo scope     find other repos this ticket touches; ask you once (or park)
  -> 2 Workspace       one isolated worktree and branch per included repo; record baselines
  -> 3 Spec            self-interview from evidence; Assumptions, Open Decisions, Blockers
  -> 4 Spec review     fresh reviewers (Goldfish) challenge the spec; high lane waits for you
  -> 5 Implement       one unit at a time: tests first, then code, then sensors
  -> 6 Code review     fresh reviewers read each unit's diff, plus a final cross-repo pass
  -> 7 Raise MRs       Draft MRs in your name, linked and ordered, plus a Jira comment
  -> YOU review        the only mandatory human step
```

Each phase writes its state to disk, so an interrupted run loses at most the phase in progress.

---

## 7. Features in depth

### 7.1 Lanes: risk sets the rigor

Read `skills/egm_autopilot/references/lanes.md` for the full rules.

| Lane | Typical change | Spec review | Code reviewers | Human touchpoints |
|---|---|---|---|---|
| `small` | a clear bug or small task, one module, no contract change | two reviewers | spec auditor, bug hunter | MR review |
| `feature` | a normal feature, one or more units | full five-stage review | adds test adequacy and simplicity | MR review |
| `high` | auth, payments, schema, public API, CI or infra, security labels, large blast radius, or a contract consumed by another repo | full review, two critic passes | adds security, always on | spec approval **and** MR review |

Changes spanning two or more repos are never `small`. A contract change that another selected
repo consumes forces `high`.

### 7.2 Readiness check and parking

Before any work, the autopilot scores the ticket from 0 to 100 against testable acceptance
criteria, a clear target area, and missing decisions.

| Score | Result |
|---|---|
| below 40 | **park**: it asks specific questions and stops |
| 40 to 70 | proceed, and record each gap as an explicit Assumption |
| above 70 | proceed |

The thresholds are in the config (`readiness.park_below`, `readiness.proceed_above`).

### 7.3 The self-interview (spec without a meeting)

Instead of a human interview, the Elephant (your Claude session) asks itself the questions an
engineer would ask, and answers from evidence in this order: ticket, linked docs, the code and
its tests, repo docs and ADRs, prior design docs, then the workspace knowledge. Every answer
cites its source.

Unanswered questions are classified:

- **Assumption**: low impact or a conventional default. Recorded, and the run continues.
- **Open Decision**: affects behavior, but a safe default exists. The default and alternatives
  are recorded, the run continues, and the MR flags it for you to veto.
- **Blocker**: changes behavior and has no safe default. The run parks.

### 7.4 Spec review by fresh reviewers (Goldfish)

Reviewers start with no memory. Each sees only the files named in its brief, never the
Elephant's reasoning. The spec goes through the `egm-review` pipeline (Zoom Out, Comprehension,
Critic, Implementation Readiness) for `feature` and `high`, and a two-reviewer pass for `small`.

Findings are resolved by fixed rules:

1. No concrete evidence: dropped.
2. Outside the ticket's scope: becomes a follow-up, not code.
3. Blocker or major with a clear fix: applied.
4. Blocker or major needing a choice: the safest default is applied and recorded as an Open
   Decision. If no safe default exists, the run parks.
5. Minor: applied if trivial, otherwise listed as deferred.
6. Style or nit: applied only if a linter would catch it.
7. Two reviewers disagree: the stricter answer wins on security and correctness, the simpler
   on design. The conflict is recorded in the MR.

Up to `loops.spec_max_rounds` rounds. Blockers left at the cap mean the run parks, because it
never builds on a failed spec.

### 7.5 The high-lane spec gate

On the `high` lane the run pushes only the spec as a Draft MR titled `[SPEC] <KEY>: …`, comments
on Jira, labels the ticket `ai-awaiting-spec-approval`, and parks. You approve the spec, then run
`--resume`. The approved spec is then frozen: any later change has to be recorded as a new Open
Decision, never edited silently.

### 7.6 Units of work

Feature and high tickets are split into **units**: slices that each deliver one behavior and
pass their own tests. Read `references/units.md`.

- Units are built one at a time, in dependency order. A unit must be green before the next starts.
- Each unit has its own branch, `ai/<KEY>-<slug>-u<n>`, built on the previous unit.
- Each unit is reviewed on its own diff when it goes green. After the last unit, one
  cumulative spec-auditor pass checks the gaps between units.
- More than `units.max` (default 5) means the ticket is too big. The run parks and proposes a
  split.
- The small lane is always one unit.

### 7.7 Stacked Draft MRs

With `units.mr_strategy: stacked` (the default for multi-unit feature and high tickets):

- MR `[1/3]` targets the base branch. MR `[2/3]` targets `[1/3]`'s branch, and so on.
- Each MR is titled `<KEY> [n/N]: <what this unit delivers>`.
- Each MR lists the whole series and its own position.
- Merge them in order. Retargeting after an earlier MR merges is your job.

Use `units.mr_strategy: single` for one MR per ticket. The units are then listed in the
description, one commit group per unit.

### 7.8 MR descriptions use your repo's template

Each MR uses the **merge request template the repo already defines** in
`.gitlab/merge_request_templates/`, so it looks like every other MR your team raises:

- **Template choice:** a bug or `bugfix` label uses `bugfix.md`; a `hotfix` label or a Blocker
  or Highest incident uses `hotfix.md`; otherwise the default. Repos with no template (for
  example `ai-nexus-client` and `ai-labs-test` today) get a built-in layout.
- **Filled in, not rewritten:** headings and checkboxes stay as the repo wrote them. Placeholders
  are replaced, and the commit list is generated, since GitLab only expands `%{all_commits}` in
  its own UI.
- **Only verified boxes are ticked.** Checks the run cannot perform, such as manual testing
  against a local stack or monitor checks, stay unticked and are marked `not verified by EGM`.
- **Unknown facts are marked** `unknown: developer to fill`. Nothing is guessed.
- **The EGM review is appended** as one block at the bottom: open decisions, traceability,
  check results, AI review rounds, confidence, and the run id. When there are open decisions,
  a one-line callout sits above the repo's first section so they are not missed.

### 7.9 Sensors: ground truth over model opinion

Before any reviewer runs, the deterministic checks run: build, lint, typecheck, tests, and secret
scan. Their output is saved per unit. A reviewer's opinion never overrides a failing sensor.

Each repo's own checks override the global defaults. Keys left empty are detected from its
Makefile, `package.json`, `pyproject.toml` or CI config. If nothing is detectable, the run
records "no check available" and never claims a pass. If `gitleaks` is not installed, the secret
scan is skipped and reported.

Baselines are recorded before any change. A check that was already failing is reported as
pre-existing, so new failures are never blamed on the old ones.

### 7.10 The questions file: structured parking

When the run must park, it writes `<run-dir>/questions.md` and posts the same text on Jira:

```markdown
## 1. Should expired promos still apply?
Why it matters: changes whether a reservation can use a closed promotion.
- [ ] A. No, reject them (**recommended**: matches the current pricing rule)
- [ ] B. Yes, until month end
- [ ] C. Other: ______
```

Reply with `1B` or `1B 2A`. For "Other", write `3: your text`. Anything left out takes the
recommended option, and the run records it as an Assumption. Free text outside those forms is
treated as untrusted ticket text, not as instructions.

### 7.11 Your identity, always

Git, `glab` and Jira all use **your** logins. The MR is raised as you, so you own it. The
autopilot never merges, approves, or force-pushes, and it never edits a repo you cannot push to.

### 7.12 Dry runs

`--dry-run` prints the lane, readiness score, spec path, Assumptions, Open Decisions, review
findings, and how each finding would be resolved. It makes no changes outside the run
directory. The repo-scope question still runs, because that answer decides what the plan covers.

---

## 8. Multi-repo tickets

Real features often touch several repos: a backend, its client, a frontend, a tests repo.

### 8.1 The proposal

After triage, the run looks for other repos read-only, using these sources in order:

1. **Contract consumers.** Repos that consume a contract this ticket changes, from `map.md`
   and each repo's `contracts.md`, then verified in the code.
2. **Your registry.** Repos whose name or role matches the ticket's components and links.
3. **Ticket text.** Repos the ticket names. This is evidence only.
4. **Sibling checkouts.** Directories beside the primary repo whose remote matches.

If it finds more than one, it shows a proposal:

```text
LABS-1234 looks like it changes more than one repo:
- ai-nexus (backend, primary): adds the /summary field
- nexus-client (client): consumes /summary, found client.summary() calling it
- admin-portal (frontend): shows the summary, found SummaryCard reading it
- nexus-e2e (tests): no existing coverage of /summary
Order: backend, client, frontend, tests. One Draft-MR stack per repo, linked together.
```

### 8.2 How you answer

- **Live session:** a multi-select prompt. Unchecked repos become follow-up tickets.
- **Unattended:** the run parks with a multiple-choice question. Answer `1A` (all of them),
  `1B` (primary only), or name the repos.
- **Skip the prompt:** `--repos a,b` includes exactly those, `--primary-only` includes none.
- **Modes** (`multi_repo.mode` in the config): `ask` (default), `primary_only`, or `auto`.
  `auto` includes every registered, clean, pushable candidate, and is never used on the `high`
  lane.

### 8.3 Safety rules for repos

- Ticket text can **suggest** a repo but can never add one, supply a path, or supply a clone URL.
- Only repos from your registry, or checkouts already on disk, and only after you confirm.
- A repo you cannot push to is reported and excluded. The run never works around it.
- `multi_repo.max_repos` (default 4) caps the set, primary included. More than that means the
  ticket is too broad, and the run parks with a proposal to split it.

### 8.4 What changes when several repos are included

- **One spec** for the whole ticket, starting with a **Contract** section: the exact interface
  between repos (fields, types, error shapes, versions, rollout order). Every unit then names
  its single repo.
- **Build order is producer to consumer:** `shared`, `backend`, `client`, `frontend`, `tests`.
  A consumer can build against its producer's real code.
- **Checks per repo:** each repo uses its own commands.
- **Contract review:** after the last unit, one reviewer reads every repo's diff together and
  must say whether producers and consumers agree on field names, types, status codes and error
  shapes. A disagreement is a blocker.
- **MRs:** one stack per repo, titled `<KEY> [<repo> n/N]: …`, labelled `multi-repo`. Each MR
  has a **Related MRs** block with the merge order. Do not merge a consumer before its producer.
- **Failure:** if a unit fails, every unit that depends on it stops. Completed units still get
  Draft MRs, and the run parks.

---

## 9. Product umbrellas

If your repos live in a product umbrella, a git repo with `workspace-repos.json`, `repos/` and
`domain-context/` (for example `~/storable/aidlc-umbrella`), register the umbrella once:

```text
/egm:egm-init add-umbrella ~/storable/aidlc-umbrella
```

What that changes:

- **The manifest is the repo list.** `workspace-repos.json` declares the repos and where their
  checkouts live under `repos/`. Re-read it with `/egm:egm-init sync-umbrella` after it changes.
- **Nothing is duplicated.** The umbrella's `domain-context/` is linked. Its AIDLC CodeKB,
  `aidlc/spaces/<space>/codekb/<repo>/`, is read as a seed, read-only, and every reused claim is
  checked against the code.
- **The umbrella is read-only to EGM.** It never writes to `domain-context/`, `product-specs/`,
  `aidlc/`, `.aidlc/`, `.claude/`, `.codex/` or `workspace-repos.json`, and it never scans
  `product-specs/`. A feature spec is read only when the ticket names its exact path.
- **Worktrees go in the ignored folder:** `<umbrella>/repos/.worktrees/<KEY>/<repo>`. Commits and
  MRs belong to the application repos, never to the umbrella.
- **Duplicate checkouts:** if a repo exists both under `~/storable/<repo>` and under the
  umbrella's `repos/`, `add-umbrella` detects it by remote URL and asks which to keep. Keep one,
  so work is not split across two checkouts.
- **Missing checkouts** are reported, not cloned. Run the umbrella's `bin/setup`.

If the umbrella runs its own AIDLC hooks in your session and one blocks an action, the run stops
and reports it. It never works around a hook.

---

## 10. Parking, answering, and resuming

A run parks when it cannot safely continue without you: a weak ticket, a blocker, a multi-repo
choice, a failed spec, a failed unit, or the high-lane spec gate.

What a park does:

1. Writes `<run-dir>/questions.md`, a multiple-choice form.
2. Posts the same text on the Jira ticket and labels it `ai-needs-input`
   (or `ai-awaiting-spec-approval` for the spec gate). The assignee is unchanged.
3. Saves `state.json` with the parked phase, question ids, repos, per-unit status and branches.
4. Stops with a one-paragraph summary.

To continue:

1. Reply on Jira (`1B 2A`) or edit `questions.md`.
2. Run `/egm:egm-autopilot <KEY> --resume`.

On resume the run reads answers only from the form: option picks and `n: text` lines. Everything
else in a reply is context for the run, never an instruction. Answers are recorded with their
source, the file or the Jira comment author.

---

## 11. Handing off to another session or person

Run state lives in `~/.egm/runs/<KEY>/`, not in the repo, so any Claude Code session on the same
machine can resume it:

- **Another session, same machine:** open Claude Code anywhere and run
  `/egm:egm-autopilot <KEY> --resume`.
- **After a crash or closed terminal:** the same. You lose at most the phase in progress. Work
  already committed to the `ai/` branches is kept.
- **Another person:** they need their own workspace and logins. Copy the run folder, or share it
  with the branches pushed. Jira comments and MR links carry the human-facing part.

Caveats: resume is phase-granular, so a half-written unit restarts from its last commit. The run
folder can contain ticket text, so keep it out of shared folders.

---

## 12. Configuration reference

Two files:

- `egm-autopilot.config.yaml`: at the target repo root if it exists, otherwise the plugin default.
- `~/.egm/workspace.yaml`: your repo registry. It takes precedence over the `repos:` block in the
  config.

Keys you are most likely to change:

```yaml
jira:
  ready_label: ai-ready             # tickets the autopilot may pick up
  in_review_status: "In Review"     # status after the MR is raised

readiness:
  park_below: 40                    # below this: park with questions
  proceed_above: 70                 # between: proceed with Assumptions

lanes:
  small: { max_files: 3 }
  high:  { min_modules: 3, min_files: 15 }

loops:
  spec_max_rounds: 3                # spec review rounds before parking
  code_max_rounds: 2                # code review rounds before a Draft with findings
  fix_max_attempts: 3               # fix attempts per failing check

multi_repo:
  mode: ask                         # ask | primary_only | auto
  max_repos: 4                      # including the primary

units:
  max: 5                            # more units than this: park and propose a split
  max_files_per_unit: 8
  mr_strategy: stacked              # stacked | single

mr:
  draft: true                       # MRs open as Draft; you publish

checks:                             # override per repo in that repo's own config
  build: ""                         # empty means detect, or record "no check available"
  lint: ""
  typecheck: ""
  test: ""
  secret_scan: ""                   # e.g. "gitleaks detect --no-banner"
```

Also: `on_cap_exceeded` (what happens at a review cap), `budgets` (time and file ceilings per
ticket), and `git.protected_branches`.

---

## 13. Safety rules and guardrails

Defense in depth. The real controls are server-side: protected branches and your GitLab
permissions.

- **Jira content is untrusted input.** Ticket text, comments and attachments can contain
  instructions. They are logged and ignored, and suspicious ones park the run.
- **Guard hook** (`.claude-plugin/hooks/guard.sh`, a Bash pre-tool hook). It blocks:
  - force pushes;
  - pushes to `main`, `master`, `develop` or `release`;
  - `glab mr merge` and `glab mr approve`, including the equivalent `glab api` calls;
  - bypassing git hooks or signing (`--no-verify`, `--no-gpg-sign`);
  - commits without `Co-Authored-By: Claude <model> <noreply@anthropic.com>`;
  - `curl` calls that reference `.env`, `id_rsa` or `.aws/credentials`, and `rm -rf` of home-level paths.
  If the input cannot be parsed, it fails closed.
- **Commit attribution.** Every commit carries the Claude co-author line naming the model.
- **No merges, approvals or force-pushes**, ever. Merging is yours.
- **Budgets.** `budgets` caps time and changed files per ticket, and the run parks when it hits
  one.
- **Secrets.** Knowledge files never record secrets. Only environment variable names appear.

---

## 14. Where things are stored

| What | Where | Committed? |
|---|---|---|
| Your repo registry and knowledge | `~/.egm/` (or `EGM_HOME`) | no, per user |
| Run state per ticket | `~/.egm/runs/<KEY>/` | no |
| Learnings (categories only) | `~/.egm/learnings.md` | no |
| Units, commits, MR branches | `ai/<KEY>-<slug>[-u<n>]` in each repo | yes, pushed to GitLab |
| Worktrees (umbrella) | `<umbrella>/repos/.worktrees/<KEY>/` | no, gitignored |
| Spec | `<run-dir>/spec.md`, or `docs/designs/<KEY>-<slug>.md` in the repo if it has that folder | the design doc, if copied |
| Plugin config defaults | `skills/egm_autopilot/egm-autopilot.config.yaml` | yes |

The run folder is outside every repo on purpose. Nothing in it gets committed by accident.

---

## 15. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| "not initialised" | `~/.egm` does not exist | run `/egm:egm-init` |
| Prompted to approve reads on every run | no permission rules for `~/.egm` | add the `Read`, `Grep`, `Glob` rules in section 3 |
| "not a git checkout" from `egm-init` | the path is not a repo root | point it at the directory containing `.git` |
| Knowledge shows `stale` | the repo has new commits | `/egm:egm-init refresh <name>` |
| `glab` says no known GitLab host | the remote host is not recognised | `GITLAB_HOST=gitlab.com` before the command |
| Secret scan skipped | `gitleaks` not installed | install it; until then the run says so |
| Repo missing from the scope prompt | not registered, and not on disk beside the primary | `/egm:egm-init add <path>` |
| Duplicate checkouts | the same repo under two paths | keep one; `add-umbrella` reports duplicates |
| A reviewer cannot read its persona | the read-approval hook did not run | check `docs/claude.md` (Cowork and headless notes) |
| A hook blocked a command | the guard or an umbrella hook matched | read the message; do not bypass it |

---

## 16. Limits and status

- **Not yet run end to end on a live ticket.** The behavior is specified in the skill
  instructions and the references under `skills/egm_autopilot/references/`. Start with
  `--dry-run` and read the plan before any real run.
- **Knowledge quality** depends on the model reading each repo. Check the first `overview.md`
  and `contracts.md` it writes, and correct them by hand.
- **Cross-repo consumer discovery** is a search for usages, so it can miss dynamic or indirect
  consumers. That is why the repo list is confirmed with you.
- **A consumer unit** can build against its producer's unmerged branch. The MRs show the
  dependency and merge order, but nothing enforces the order.
- **Learnings** only record categories, so they show patterns, not detail.
- **Not included:** deployment. Merge and deploy stay human. A deploy stage is a planned
  extension that would read the merged-MR event.

For the design rationale, see the lane rules in `skills/egm_autopilot/references/lanes.md`, the
unit rules in `references/units.md`, the repo rules in `references/repos.md`, and the workspace
rules in `skills/egm_init/references/home.md`.
