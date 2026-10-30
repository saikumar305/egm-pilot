<!--
Copyright 2026 Google LLC.
SPDX-License-Identifier: Apache-2.0
-->

# EGM Pilot help

One section per skill. `egm-help` prints the overview, or one section when given a skill
name. Each skill prints its own section when called with `--help` or `-h`.

## overview

EGM Pilot: a task or an idea to a reviewed Draft merge request, built on the
Elephant-Goldfish Model. The Elephant (this session) holds the context and writes; Goldfish
reviewers start with no memory and see only the files they are given.

Shape the idea
  /egm-pilot:egm-brainstorm     idea -> concepts_brief.md, challenged by fresh reviewers
  /egm-pilot:egm-draft          brief -> design_draft.md, one approved section at a time
  /egm-pilot:egm-review         design doc -> five-stage Goldfish review report
  /egm-pilot:egm-resolve        review findings -> fix, contest or defer, one at a time

Keep docs honest
  /egm-pilot:egm-review-loop    any document -> chosen reviewers, approved fixes, repeated
  /egm-pilot:egm-drift-report   docs vs. today's code -> list of disagreements
  /egm-pilot:egm-bootstrap      code subtree -> a README per directory, written from code

Ship the change
  /egm-pilot:egm-init           register your repos once (~/.egm); optional
  /egm-pilot:egm-autopilot      task or idea -> spec, review, tests-first build, Draft MRs

Common paths
  Design first:   brainstorm -> draft -> review -> resolve
  Build a task:   init (once) -> autopilot KEY --dry-run -> autopilot KEY
  Build an idea:  autopilot --idea "<text>" --interactive

More
  /egm-pilot:egm-help <skill>   details for one skill (for example: egm-help autopilot)
  /egm-pilot:<skill> --help     the same, from the skill itself
  Guide: docs/autopilot.md      Site: https://saikumar305.github.io/egm-pilot/

## egm-brainstorm

/egm-pilot:egm-brainstorm [idea text | file]

Turns a rough idea into a clear problem and a few testable options. Asks clarifying
questions, then sends the brief to Goldfish reviewers to challenge it.

Writes: concepts_brief.md (problem, goals, options, open questions)
Next:   /egm-pilot:egm-draft concepts_brief.md

Example
  /egm-pilot:egm-brainstorm Let admins export invoices as CSV

## egm-draft

/egm-pilot:egm-draft [context file]

Writes the design document section by section; you approve each section before the next.
With no file it reads concepts_brief.md or discussion_summary.md from the working directory.

Writes: design_draft.md (feature-spec standard)
Next:   /egm-pilot:egm-review design_draft.md
Revise: edit the file, add <!-- --> comments in it, or give notes in chat

Example
  /egm-pilot:egm-draft concepts_brief.md

## egm-review

/egm-pilot:egm-review <design doc> [interactive | uninterrupted | feature_spec | implementation | 5-9]

Runs Goldfish reviewers over a design in five stages: 5 zoom-out, 6 comprehension,
7 critic, 8 second zoom-out, 9 implementation readiness. With no preset it asks which
to run. It may also ask for extra context files for the reviewers (optional).

  interactive     stages 5-9, stopping for you after each stage
  uninterrupted   stages 5-9 with no stops, one consolidated report
  feature_spec    stages 5-8: the design, without the implementation plan
  implementation  stage 9 only: the implementation plan
  5 .. 9          one stage only

Writes: consolidated_review_report.md (ranked findings with evidence)
Next:   /egm-pilot:egm-resolve consolidated_review_report.md

Example
  /egm-pilot:egm-review design_draft.md uninterrupted

## egm-resolve

/egm-pilot:egm-resolve [report or findings]

Goes through review findings with you one at a time: apply the fix, contest it, or defer it.
Run it in the session that wrote the document, so it remembers the reasoning.

Writes: the updated document and a record of each decision

Example
  /egm-pilot:egm-resolve consolidated_review_report.md

## egm-review-loop

/egm-pilot:egm-review-loop [file]

Runs reviewers you choose against any document, applies the fixes you approve, and repeats.
It asks for anything you leave out:

  target      the file, and the part of it (or "full file")
  reviewers   design_critic, structural, style, implementation_readiness,
              codebase_details, comprehension, zoom_out (or a path)
  standards   feature-spec-standard, implementation-readiness-standard,
              zoom-out-standard, heilmeier-standard, re-implementation-standard (or a path)
  context     files or folders the reviewers read first

Example
  /egm-pilot:egm-review-loop README.md

## egm-drift-report

/egm-pilot:egm-drift-report <docs directory>

Compares each design doc or README in the directory with the code as it is today and lists
where they disagree: missing features, incomplete models, changed behavior.

Example
  /egm-pilot:egm-drift-report docs/designs

## egm-bootstrap

/egm-pilot:egm-bootstrap <directory> [target filename]

Creates or updates a README for each directory in a code subtree, from the code itself:
leaf READMEs hold file contracts, parent READMEs roll them up. Documentation only; it does
not change code. Pass a different filename (for example EGM.md) to leave existing READMEs
alone.

Example
  /egm-pilot:egm-bootstrap src/

## egm-init

/egm-pilot:egm-init [add <path>... [--role r] [--name n] | refresh [name|--all] | status | remove <name>]

Sets up ~/.egm (override with EGM_HOME): a registry of your repos and short knowledge files
for each (what it is, how to build and test it, the contracts it exposes and consumes).
Autopilot reads it. Optional, but runs start faster and safer with it.

  (no arguments)   create ~/.egm and offer to add the current repo
  add <path>...    register repos; the role is inferred and you confirm it
  refresh          rebuild knowledge for one repo, or --all that changed
  status           repos, freshness and run count
  remove <name>    unregister a repo

Tip: allow Read(~/.egm/**), Grep(~/.egm/**), Glob(~/.egm/**) to skip read prompts.

## egm-autopilot

/egm-pilot:egm-autopilot <TASK-KEY|URL | --idea "<text>"|<file.md>> [options]

Takes a task (Jira is the supported tracker) or an idea to reviewed Draft MRs: intake,
risk lane, spec, Goldfish spec review, tests-first build, Goldfish code review, MR. MRs are
raised in your name; you review and merge.

Input
  KEY or URL               the task to build, for example LABS-2345
  --idea "<text>"|<file>   start from an idea instead of a task
  --ticket <PROJECT>       with --idea: file a task in PROJECT once the spec is reviewed

Mode
  (default)                unattended; parks with a question form when it needs you
  --interactive            live Q&A: you answer and approve each step
  --unattended             with --resume: switch an interactive run back

Scope
  --lane small|feature|high   override the risk lane (high adds your spec approval)
  --base <branch>             build on and target this branch (default: repo default)
  --repos <name|path>,...     attach more repos; one repo unless you add them

Control
  --dry-run                plan only: no commits, push, MR or task writes
  --stop-before-push       build and review locally, then stop for your approval to push
  --resume                 continue a parked run, after you answer its questions

Gates (config gates: commit, push, mr = auto | ask)
  Interactive always asks before push and MR. Unattended parks at an ask gate with a
  preview in ready.md; answer and --resume to push. The guard hook enforces them.

Needs: git, jq, glab (logged in as you), and the Atlassian connector for Jira tasks.

Examples
  /egm-pilot:egm-autopilot LABS-2345 --dry-run
  /egm-pilot:egm-autopilot LABS-2345 --interactive
  /egm-pilot:egm-autopilot LABS-2345 --stop-before-push
  /egm-pilot:egm-autopilot LABS-2345 --resume
  /egm-pilot:egm-autopilot --idea "Let admins export invoices as CSV" --interactive
  /egm-pilot:egm-autopilot LABS-2345 --repos orders-api,web-app --base release/2.4

Guide: docs/autopilot.md

## egm-help

/egm-pilot:egm-help [skill]

Shows the overview, or the details for one skill. The egm- prefix is optional:
"egm-help autopilot" and "egm-help egm-autopilot" are the same.
