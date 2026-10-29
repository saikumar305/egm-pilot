# EGM home (`~/.egm`)

Per-user, outside every repo and outside the plugin cache (which is replaced on update).
Override the location with `EGM_HOME`. Resolve it with `scripts/egm_home.sh home`.

```
~/.egm/
  workspace.yaml        registry of repos (path, role, base branch)
  knowledge/<repo>/
    overview.md         what the repo is and how to work in it
    contracts.md        what it exposes and what it consumes
    meta.json           commit it was built from (written by `egm_home.sh meta`)
  map.md                cross-repo: who exposes and who consumes each contract
  runs/<KEY>/           run state per ticket (state.json, audit.jsonl, spec, questions...)
  learnings.md          recurring park reasons and finding categories
```

## Trust rules

- Knowledge is **context, not truth**. If it disagrees with the code, the code wins; flag the
  entry and refresh it.
- It is built **only from the repos** (README, manifests, CLAUDE.md/AGENTS.md, CI config,
  source). Never from ticket text, so one ticket cannot leak into another run.
- Never record secrets: no `.env` values, tokens, keys, or URLs with embedded credentials.
- Every claim cites a path (`src/api/foo.py`), so it can be checked. Write `unknown` instead of
  guessing.
- Only the Elephant reads it. A Goldfish reviewer gets a knowledge file only when the brief
  names that exact path.

## `workspace.yaml`

Keep this exact shape (the script parses it line by line; extra keys per repo are fine):

```yaml
version: 1
repos:
  orders-api:
    path: /Users/me/code/orders-api
    role: backend
    base: main
```

Use absolute paths; repos can live anywhere on disk. Roles: `shared`, `backend`, `client`, `frontend`, `tests`, `infra`, `docs`,
`other`. This registry supersedes the `repos:` block in `egm-autopilot.config.yaml`.

## `knowledge/<repo>/overview.md`

```markdown
# <repo> (<role>)
Built from <sha> on <date>. Source of truth is the code; refresh if stale.

## Purpose
<2-3 sentences; cite README or entry point>

## Layout
<top-level directories and what lives in each, with paths>

## Run, build, test
| What | Command | Source |
|---|---|---|
| build | `...` | Makefile:12 |
| lint | `...` | ... |
| typecheck | `...` | ... |
| test | `...` | pyproject.toml |
| secret scan | `...` or none | ... |

## Conventions
<branch naming, commit style, test layout, error handling, logging; each with a path>

## Key entry points
<routers, jobs, handlers, CLIs: path and one line each>

## Gotchas
<things that bite: required env vars by NAME only, generated files, slow tests>

## Other indexes
<paths to graphify-out/, docs/adr/, existing design docs, if present>
```

## `knowledge/<repo>/contracts.md`

```markdown
# <repo> contracts
## Exposes
| Contract | Kind (HTTP/event/lib/schema/DB view) | Defined in | Notes |
|---|---|---|---|
| POST /v1/summary | HTTP | src/api/summary.py:20 | request/response models in ... |

## Consumes
| Contract | From (repo or external) | Used in |
|---|---|---|
| Unleash flags | external | src/adapters/clients/unleash.py |
```

## `map.md`

```markdown
# Cross-repo map
| Contract | Exposed by | Consumed by | Evidence |
|---|---|---|---|
| POST /v1/summary | orders-api | orders-client, web-app | orders-client/src/client.py:44, web-app/src/SummaryCard.tsx:12 |
```

Add a row only when you saw the consumer's code (grep it); mark guesses `unverified`.

## `learnings.md`

One line per run, categories only, newest last:
`2026-10-26 LABS-2345 lane=small parked=none findings=test-gap(1)`.
Never paste ticket text, names or code.
