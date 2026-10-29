# Elephant-Goldfish Model (EGM)

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Website](https://img.shields.io/badge/Website-egm.dev-black.svg)](https://egm.dev)

Elephant-Goldfish Model (EGM) is an open-source plugin for Spec-Driven Development with AI coding agents. Deep-context Elephant sessions draft specifications, and isolated zero-context Goldfish subagents stress-test them before you write code.

EGM now runs in two modes:

- **Spec-driven development:** brainstorm, draft, and review a design doc with isolated Goldfish reviewers.
- **EGM Autopilot:** take an assigned Jira ticket to a reviewed, Draft merge request, in your own name, with a single human step at the end.

It runs in Claude Code, with a per-user workspace (`/egm:egm-init`) that teaches it your repositories.

## Features

- **Jira ticket to Draft MR:** `/egm:egm-autopilot <KEY>` runs intake, risk-based triage, a spec, tests-first implementation, isolated code review, and opens the MR. You review and merge.
- **Risk lanes:** `small`, `feature` and `high`. Auth, payments, schema, public API, CI or infra changes, and cross-repo contracts force `high`, which adds a human spec approval before any code is written.
- **Multi-repo tickets (optional):** a run changes one repo by default. Attach more with `--repos <name|path>,...`, from anywhere on disk. Attached repos are built producer-to-consumer and reviewed together for contract agreement. The run may suggest other likely affected repos, but never adds them itself.
- **Units and stacked MRs:** large tickets are split into small units, each built and reviewed on its own, and raised as a stack of linked Draft MRs (`KEY [1/3]`, `[2/3]`, ...).
- **Structured questions:** when a run needs an answer it parks with a multiple-choice form (`1B 2A`) on Jira. Resume with `--resume`.
- **Your repo's MR template:** MRs follow the repo's own `.gitlab/merge_request_templates/`. Only verified checks are ticked, and the EGM review is appended as one block.
- **Global workspace:** `/egm:egm-init` optionally registers your repos and builds short knowledge files per repo: what it is, how to build and test it, and which contracts it exposes and consumes. Knowledge is checked against the commit it was built from and refreshed when stale.
- **Guardrails:** a Bash hook blocks force pushes, pushes to protected branches, merging or approving MRs, hook bypasses, and commits without the Claude co-author line. Jira content is treated as untrusted input.
- **Isolated reviewers (Goldfish):** reviewers start with no memory and see only the files in their brief, never the author's reasoning.

## Install

| Harness | Install |
| :--- | :--- |
| **Claude Code** | `claude plugin marketplace add google/elephant-goldfish-model && claude plugin install egm@egm` |
| **Local copy** | `claude --plugin-dir /path/to/elephant-goldfish-model` (use a uniquely named copy if an `egm` plugin is already installed) |
| **Claude Cowork** | See [Claude Code integration](docs/claude.md#claude-cowork) |

Requires Claude Code 2.1.271 or later. Autopilot also needs `git`, `jq`, `glab` (logged in as you), and the Atlassian connector in Claude Code.

## Quickstart

1. **Ideate & Stress-Test**: Run `/egm-brainstorm` to explore problem boundaries and test early concepts with a Goldfish swarm.
2. **Draft**: Run `/egm-draft` to convert the concept brief into a living design document under `docs/designs/<feature>.md`.
3. **Review & Resolve**: Run `/egm-review docs/designs/<feature>.md` to run the multi-stage Goldfish reviewer swarm.
4. **Submit & Implement**: Submit the verified design doc via pull request and implement code against the approved specification.

In Claude Code, commands use the `/egm:` prefix (for example `/egm:egm-brainstorm`).

For setup details, see [Claude Code integration](docs/claude.md).

## EGM Autopilot: Jira ticket to reviewed MR

```text
/egm:egm-init                                # once per machine: register your repos
/egm:egm-autopilot LABS-2345 --dry-run       # plan only: no push, no MR, no Jira writes
/egm:egm-autopilot LABS-2345                 # the real run
/egm:egm-autopilot LABS-2345 --resume        # continue after answering a parked question
```

Options: `--lane small|feature|high`, `--base <branch>`, `--repos <name|path>,...` (attach more repos; optional), `--resume`, `--dry-run`.

```text
Jira -> intake -> lane -> [attached repos] -> worktrees -> spec -> spec review -> build (units) -> code review -> Draft MRs -> you review
```

The full how-to is in [docs/autopilot.md](docs/autopilot.md), and a step-by-step animated walkthrough is in [docs/autopilot-flow.html](docs/autopilot-flow.html). Open the HTML in a browser.

**Status:** the skill and its references are written, but autopilot has not yet run end to end on a live ticket. Start with `--dry-run`.

## Workspace: `/egm:egm-init`

The per-user workspace lives in `~/.egm` (override with `EGM_HOME`). It contains:

- `workspace.yaml`: the repos you work across, with their paths, roles and base branches.
- `knowledge/<repo>/`: `overview.md` (purpose, layout, build and test commands) and `contracts.md` (what the repo exposes and consumes), each recording the commit it was built from.
- `map.md`: which repo exposes and which consumes each contract.
- `runs/<KEY>/`: state for each ticket run, so `--resume` works from any directory.

```text
/egm:egm-init                                  # create ~/.egm and offer to add the current repo
/egm:egm-init add ~/code/orders-api            # register a repo (role inferred, you confirm)
/egm:egm-init refresh --all                    # rebuild knowledge for repos that changed
/egm:egm-init status                           # repos, freshness and run count
```

Add these permission rules so Claude does not prompt on every read of the workspace:
`Read(~/.egm/**)`, `Grep(~/.egm/**)`, `Glob(~/.egm/**)`.

Knowledge is context, not truth: when it disagrees with the code, the code wins. It is never built from ticket text and never records secrets.

## Skills

| Skill | Command | Description |
| :---- | :------ | :---------- |
| **Autopilot** | `/egm:egm-autopilot` | Jira ticket to reviewed Draft MR: lanes, units, optional attached repos, parked questions and resume. |
| **Init** | `/egm:egm-init` | Per-user workspace: optionally registers repos and builds their knowledge. |
| **Brainstorm** | `/egm:egm-brainstorm` | Zero-doc ideation tool using a multi-lens Goldfish shootdown swarm to stress-test early concepts. |
| **Draft** | `/egm:egm-draft` | Iterative, section-by-section markdown design specification compiler. |
| **Review** | `/egm:egm-review` | Multi-stage verification pipeline orchestrator (Zoom Out -> Comprehension -> Critic -> Readiness). |
| **Review Loop** | `/egm:egm-review-loop` | Concurrent review subagent dispatch engine supporting direct and hierarchical dispatch. |
| **Review Resolve** | `/egm:egm-resolve` | Interactive triage and automated patch application engine for review findings. |
| **Drift Report** | `/egm:egm-drift-report` | Sequential AST scanner detecting divergence between checked-in specs and live code. |
| **Bootstrap** | `/egm:egm-bootstrap` | Recursive bottom-up codebase documentation generator and sentinel-block upserting engine. |

## Layout

```text
.claude-plugin/        plugin manifest, Claude reviewer adapters, read-approval and guard hooks
skills/egm_autopilot/  autopilot skill, config and references (lanes, units, repos, questions, MR template)
skills/egm_init/       workspace skill and scripts/egm_home.sh (layout, registry, freshness)
skills/egm_*/          the design-document skills
agents/                canonical reviewer personas, shared by every adapter
resources/             document standards and execution instructions
docs/                  Claude Code integration, autopilot guide and walkthrough
```

## Philosophy

EGM uses two animal metaphors to structure AI agents across the software development lifecycle:

* 🐘 **The Elephant (Remembers Everything)**: Deep-context agents load system history, architecture diagrams, component boundaries, and user journeys. The Elephant runs structured brainstorming, probes operational limits, and drafts comprehensive specifications.
* 🐠 **The Goldfish (Zero-Context Memory)**: Stateless, isolated subagents read only the draft spec and live source code, without conversational bias. The Goldfish swarm stress-tests designs from conflicting perspectives. Personas in `agents/` include Design Critic, Naive Reader, Tech Lead, Codebase Auditor, Structural Validator, Style Editor, and Zoom Out Architect.
* 🧑‍💻 **The Human (Owns the Outcomes)**: AI is an exploration partner and automated auditor, while human engineers own architectural decisions, trade-offs, and final outcomes.

For the foundational essay introducing this methodology, see Dave Rensin's article: [Elephants, Goldfish, and the New Golden Age of Software Engineering](https://medium.com/@drensin/elephants-goldfish-and-the-new-golden-age-of-software-engineering-c33641a48874).


## License

Apache 2.0 License applies to this project - see the [LICENSE](LICENSE) file for details.

This is not an officially supported Google product.
