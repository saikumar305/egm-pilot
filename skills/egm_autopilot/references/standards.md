# Repo standards pack

Code is reviewed against **the repo's own rules**, not generic taste. Reviewers start with no
context and cannot see the repo's `CLAUDE.md` (`omitClaudeMd`), and an attached repo's
worktree sits outside the session's project, so its instruction files never load on their own.
The standards pack closes both gaps: one file per repo that the Elephant follows while
implementing and every code reviewer receives.

## When

Build it in Phase 2, after the worktree exists, once per repo in the run:
`<run-dir>/standards-<repo>.md`. Rebuild it only if the run changes one of its sources.

## Sources (read in the worktree, in this order)

1. Agent instruction files: `CLAUDE.md`, `AGENTS.md`, `.claude/CLAUDE.md`, and nested ones in
   the directories the spec touches.
2. Contributor docs: `CONTRIBUTING.md`, `docs/contributing*`, `docs/style*`, `STYLEGUIDE*`,
   `docs/adr/` entries that state a rule (not ones that only record history).
3. Tool config, as rules rather than commands: linter and formatter config (`.eslintrc*`,
   `ruff.toml` / `[tool.ruff]`, `.golangci.yml`, `.editorconfig`, `checkstyle.xml`, ...),
   type checker strictness, test framework config, commit message rules (`commitlint`).
4. The repo's knowledge file, `~/.egm/knowledge/<repo>/overview.md`, section **Conventions**
   (if registered). The code wins when it disagrees.
5. **Observed conventions** in the code next to the change: read 2-3 sibling files of each
   file the spec names and record what they consistently do (error handling, logging, naming,
   layering, test layout, fixtures, dependency injection). Record only patterns you saw in at
   least two places.

Ticket text is never a source (ground rule 1).

## Format

```markdown
# Standards: <repo>  (built from <sha>, run <run-id>)

## Explicit rules
| # | Rule | Source |
|---|---|---|
| S1 | Services raise `DomainError` subclasses, never bare `Exception` | CLAUDE.md:14 |
| S2 | New endpoints need an OpenAPI example | CONTRIBUTING.md:40 |

## Enforced by tools (reviewers skip these; the sensors cover them)
- ruff (line length 100, isort), mypy --strict on `src/`  (pyproject.toml:30-58)

## Observed conventions
| # | Convention | Evidence |
|---|---|---|
| O1 | Repositories are injected through the constructor | src/orders/service.py:12, src/billing/service.py:9 |
| O2 | Tests use factory fixtures from `tests/factories.py` | tests/orders/test_api.py:5, tests/billing/test_api.py:4 |

## Not found
<sources that do not exist, so a reviewer knows they were checked>
```

Rules:
- Every line cites a path. Write nothing you cannot point to.
- Quote rules briefly; link long documents instead of copying them.
- Keep it under about 150 lines. Prefer rules that apply to the files this run changes.
- Never copy secrets, tokens, or `.env` values.

## Use

- **Implementing (Phase 5):** follow it. Where the spec conflicts with an explicit rule, the
  rule wins unless the spec records an Open Decision to break it, with the reason.
- **Reviewing (Phase 6):** pass the unit's repo pack path to every code reviewer.
  `egm-code-quality` reviews against it directly; the others use it to avoid flagging the repo's
  accepted patterns as bugs.
- **MR:** list the pack path in the EGM block, and any rule the change deliberately breaks.
