---
name: egm-init
license: Apache-2.0
disable-model-invocation: true
description: >-
  Sets up and maintains the per-user EGM home (~/.egm): a registry of your repos and
  a knowledge base about each one (what it is, how to build and test it, what contracts it
  exposes and consumes) plus a cross-repo map. egm-autopilot reads it so it understands your
  repos before starting any ticket. Use to initialise, add or remove a repo, refresh stale
  knowledge, or check status.
---

# EGM Init: the global workspace

Read `${CLAUDE_PLUGIN_ROOT}/docs/claude.md` first, then
`${CLAUDE_PLUGIN_ROOT}/skills/egm_init/references/home.md` (layout, templates, trust rules).

The helper script owns the layout, the repo list and the freshness check:
`SCRIPT="${CLAUDE_PLUGIN_ROOT}/skills/egm_init/scripts/egm_home.sh"`. Run it with Bash. You
read the repos and write the knowledge files.

Usage: `/egm:egm-init [add <path>... [--role r] [--name n] | refresh [name|--all] | status | remove <name>]`
With no arguments: initialise, then offer to add the current directory's repo.

Registering is optional. Repos are independent checkouts wherever they live on disk; they do
not need a shared parent folder or manifest. The registry only gives them short names for
`--repos` and lets knowledge be built ahead of time. The autopilot also accepts plain paths.

This skill is interactive. Unlike the autopilot, you may ask the developer questions.
It **never modifies the repos it reads.**

## init
1. `"$SCRIPT" init` (idempotent; never overwrites). Report the home path.
2. Tell the developer once how to let Claude read it without prompts (a permission rule is
   theirs to add; do not edit their settings yourself):
   `Read(~/.egm/**)`, `Grep(~/.egm/**)`, `Glob(~/.egm/**)`. Offer `/update-config` for it.

## add <path>...
For each path:
1. Verify it is a git checkout (`git -C <path> rev-parse --show-toplevel`). Use the top level.
2. Name: `--name`, else the directory name. Refuse a name already in `workspace.yaml`.
3. Role: `--role`, else infer from files and propose it (for example FastAPI/Django/Spring
   service is `backend`; an SDK or API wrapper is `client`; React/Vue/Angular app is
   `frontend`; a repo of only tests is `tests`). Confirm roles with the developer in one
   question when adding several repos.
4. Base branch: the remote default branch (`git symbolic-ref refs/remotes/origin/HEAD`), else
   `main`.
5. Add the block to `workspace.yaml` in the exact shape in `home.md` (absolute path). If the
   file still has `repos: {}`, replace that line with `repos:` and the first block.
6. Build the knowledge (next section), then `"$SCRIPT" meta <name>`.

After the last repo, build or update `map.md`.

## Build knowledge for one repo
Read only the repo. Sources: README and docs, manifests (`pyproject.toml`, `package.json`,
`pom.xml`, ...), `CLAUDE.md`/`AGENTS.md`, Makefile and CI config, the directory tree,
entry points (routers, handlers, jobs, CLIs), API/schema definitions (OpenAPI, protobuf,
GraphQL, event schemas, shared type packages), and outgoing HTTP/queue/DB calls.
If `graphify-out/` or `docs/adr/` exists, link it under "Other indexes" instead of copying.

Write `knowledge/<name>/overview.md` and `contracts.md` using the templates. Follow the trust
rules: cite a path for every claim, write `unknown` instead of guessing, no secrets, no ticket
text. For commands, prefer what CI runs.

With two or more repos, use one read-only subagent per repo in parallel. Give each only its repo
path, the template path and the rules, and have it return the two files' content. You write them
to `~/.egm` yourself, so subagents never write outside the repos' read access.

Do **not** run `egm-bootstrap`: it writes READMEs into the repo. Offer it as a separate,
explicit step only if the developer asks.

## map.md
From every repo's `contracts.md`, build the cross-repo table. For each "Exposes" row, grep the
other registered repos for the consumer; add a row only with an evidence path, else mark it
`unverified`. Keep rows for unchanged repos; replace rows that involve a refreshed repo.

## refresh [name|--all]
1. `"$SCRIPT" stale [name]` shows `fresh`, `stale (<n> commits)`, `unbuilt` or `missing`.
2. For `stale`: `git -C <path> diff --stat <built_from_sha>..HEAD` tells you what moved. Re-read
   those areas and update only the affected sections (and `contracts.md` if schemas, routes or
   clients changed), then `"$SCRIPT" meta <name>` and update that repo's `map.md` rows.
3. For `unbuilt`: build from scratch. For `missing`: report it and ask whether to remove it.
4. A repo with a dirty working tree is read as-is; note "built from a dirty tree" in overview.md.

## status
Print the registry (`"$SCRIPT" repos`) and freshness (`"$SCRIPT" stale`) as one table. Say how
many runs exist under `runs/` and when `learnings.md` last changed. Change nothing.

## remove <name>
Show what will be deleted (its registry block and `knowledge/<name>/`, plus its rows in
`map.md`) and ask for confirmation first. Never touch the repo itself or `runs/`.

## Finish
Summarise what was created or changed, which repos are fresh, and any `unknown` entries the
developer may want to fill in by hand. Remind them that the knowledge is context, not truth:
the code wins.
