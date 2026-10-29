# Multi-repo scope

Most real features are not one repo: a backend change needs its client, a frontend
integration, and tests. This is how the run finds those repos, asks the developer once, and
carries the decision through the rest of the pipeline.

## 1. Registry

The registry is `workspace.yaml` in the developer's EGM home (`~/.egm`, created by
`/egm:egm-init`); it takes precedence. A `repos:` block in `egm-autopilot.config.yaml` is the
fallback when no home exists. Both use the same entries. The home also holds each repo's
knowledge and the cross-repo `map.md`, which discovery (section 2) starts from. Example:

```yaml
repos:
  ai-nexus:      { path: ~/storable/ai-nexus,      role: backend }
  nexus-client:  { path: ~/storable/nexus-client,  role: client,   checks: { test: "pytest -q" } }
  admin-portal:  { path: ~/storable/admin-portal,  role: frontend, checks: { test: "npm test" } }
  nexus-e2e:     { path: ~/storable/nexus-e2e,     role: tests }
```

Roles: `shared` (schemas, types, contracts), `backend`, `client` (SDK or API client),
`frontend`, `tests` (e2e, contract, generated suites), `infra`, `docs`, `other`.
The role sets the default build order (section 5). A repo's own `checks` override the global
`checks`; unset keys fall back to detection from its Makefile, package.json or pyproject.

The **primary repo** is the repo the run starts in (the working directory), or the one the
ticket names. It holds the run directory and the spec.

## 2. Discovery (Phase 1b, read-only)

Collect candidates from these sources, strongest first. Record the evidence for each:

1. **Contract consumers.** Find the contracts the ticket changes in the primary repo (OpenAPI,
   protobuf, GraphQL, event or message schemas, shared type packages, DB views other services
   read). Search each registry repo for consumers of them.
2. **Registry match.** Registry repos whose name or role matches the ticket's components,
   labels, epic siblings, or linked issues.
3. **Ticket text.** Repos, services or URLs the ticket names. This is *evidence only*.
4. **Umbrella and workspace siblings.** In a product umbrella, the repos declared in its
   `workspace-repos.json` (registered with `umbrella: <name>`) are the candidate set, and
   `domain-context/` explains how they relate. Otherwise, directories beside the primary
   repo whose git remote matches a name above. A declared repo whose checkout is missing is
   reported, not cloned.

For each candidate record: name, role, why (the evidence and its source), the expected change
in one line, and **access** (path exists, working tree clean, remote reachable, the developer
can push or open an MR there).

Safety rules:
- Discovery changes nothing. No clone, fetch of new remotes, or edits.
- A repo enters the run only if it is in the registry or already on disk in the workspace,
  **and** the developer confirmed it (section 3). Ticket text can suggest a repo; it can never
  add one, supply a clone URL, or supply a path (ground rule 1).
- Cap: `multi_repo.max_repos` including the primary. Beyond it, the ticket is too broad:
  park and propose splitting it.
- A candidate the developer cannot push to is reported and excluded; never work around it.

If there are no candidates, say nothing and continue single-repo.

## 3. The scope gate (the one allowed up-front question)

This is the exception to "no blocking questions" and it happens once, before any work starts
(after triage, before the workspace is created). `multi_repo.mode` controls it:

- `ask` (default): show the proposal and let the developer choose.
- `primary_only`: skip the gate; list the other candidates as Follow-ups.
- `auto`: include every candidate that is in the registry, clean and pushable, and report the
  list. Never `auto` on the `high` lane.

`--repos a,b` includes exactly those registry repos and skips the prompt. `--primary-only`
skips the prompt and excludes the rest.

**Proposal text** (always shown first, in plain words):

> LABS-1234 looks like it changes more than one repo:
> - **ai-nexus** (backend, primary): adds the `/summary` field
> - **nexus-client** (client): consumes `/summary`, found `client.summary()` calling it
> - **admin-portal** (frontend): shows the summary, found `SummaryCard` reading it
> - **nexus-e2e** (tests): no existing coverage of `/summary`
>
> I would change them in this order: backend, client, frontend, tests, one stack of Draft MRs
> per repo, linked together.

**Interactive session** (a question tool is available): ask once with a multi-select question
whose options are the candidates, each described by role, evidence and expected change. Then
one follow-up only if needed, for example a path that does not exist ("Where is it checked
out?" / "Skip it"). Anything not selected becomes a Follow-up in the MR.

**Unattended** (`-p`, no question tool, or `--resume`-style runs): park, since nothing has
been started. Write question 1 in the questions file:

```markdown
## 1. This ticket looks like it spans <N> repos. Which should I change?
Why it matters: the contract between repos must be built and reviewed together.
- [ ] A. All of them: <names> (**recommended**: <why>)
- [ ] B. Only <primary>; list the others as follow-up tickets
- [ ] C. Other: ______ (name the repos)
```

Record the decision in `state.json` (`repos`: name, role, path, chosen, why) and `audit.jsonl`.
Under `--dry-run` the gate still runs (it is read-only) and the plan reports the result.

## 4. What multi-repo changes downstream

- **Lane:** two or more repos is at least `feature`. Changing a contract that another selected
  repo consumes is a **hard-trigger: `high`** (public contract), so the human spec gate applies.
- **Workspace:** one worktree and branch set per repo, same names (`ai/<KEY>-<slug>-u<n>`).
  `--base` applies to the primary repo; other repos use their default branch. Baseline checks
  run per repo with that repo's checks; red baselines are recorded per repo.
- **Spec:** one spec for the whole ticket, kept in the primary repo's run directory. It adds:
  - a **Repos** section (role, reason, base branch, expected change), and
  - a **Contract** section defining the interface between repos first: endpoints or message
    shapes, field names and types, error shapes, versioning, backward compatibility, and
    rollout order. Every other section depends on it.
- **Units:** add a `Repo` column. Order units by section 5. Units must not span repos: one
  unit, one repo.
- **Sensors:** per unit, in that unit's repo, using that repo's checks.
- **Reviewers:** each unit is reviewed on its own repo diff as before. After the last unit, run
  `egm-code-spec-auditor` once on **all repos' cumulative diffs together** (one diff file per
  repo, plus the spec's Contract section) and ask it specifically whether producers and
  consumers agree: field names, types, status codes, error shapes, versions, and the stated
  rollout order. Disagreement is a blocker.
- **MRs:** one stack per repo (`units.mr_strategy` applies within a repo). Titles
  `<KEY> [<repo> n/N]: ...`, label `multi-repo`. Every MR description has a **Related MRs**
  block listing the MRs in the other repos and the required merge order. One Jira comment
  lists all MRs grouped by repo.
- **Failure:** if a unit fails, stop every unit that depends on it (same repo or downstream
  repos). Open Draft MRs for what completed, mark the failed one `ai-needs-attention`, and park.
- **Resume:** `state.json` tracks status per repo and per unit, so `--resume` continues
  where it stopped.

## 5. Build order

Producers before consumers, so a consumer can always build against real code:

`shared` -> `backend` -> `client` -> `frontend` -> `tests` (end-to-end last)

Unit tests live with their code, in the same unit and repo. The `tests` role is for suites
that sit in their own repo (end-to-end, contract, generated coverage); it goes last because it
exercises the finished behavior. A consumer unit may build against its producer's unit branch
by local path; note that dependency in the spec and in the MR, since the producer's MR may not
be merged yet.
