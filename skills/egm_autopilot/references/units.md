# Units of work (feature and high lanes)

A unit is the smallest slice that can be built, tested and reviewed on its own. Inspired by
AI-DLC's units and bolts: short build-verify cycles instead of one large change. The goal is
MRs a human can review in minutes.

## When

- `small` lane: always exactly one unit. No stacking.
- `feature` / `high`: split the spec into units. A single unit is fine when the change is
  genuinely one slice; do not split for its own sake.

## Define units in the spec

Add a **Units** section to the spec:

| Unit | Repo | Delivers | Acceptance criteria covered | Files (expected) | Depends on |
|---|---|---|---|---|---|
| U1 | backend | <one behavior> | AC1, AC2 | `a.py`, `test_a.py` | none |
| U2 | client | ... | AC3 | ... | U1 |

A valid unit:
- Lives in exactly one repo. A change that needs two repos is two units (see `references/repos.md`).
- Delivers one behavior and leaves the build green and the tests passing on its own.
- Covers at least one acceptance criterion, and every criterion is covered by some unit.
- Contains its own tests (written first).
- Has no forward dependencies (U1 never needs U2).
- Stays within `units.max_files_per_unit`. Over that, split it.

With several repos, order units producer-to-consumer (`shared`, `backend`, `client`, `frontend`, `tests`) first, then by risk within a repo. Branch names and `git diff` bases are per repo.

Order units so the riskiest or most uncertain one comes first, so a problem surfaces early.

If the split needs more than `units.max`, the ticket is too large: PARK with a question
proposing how to split the Jira ticket (use the questions file).

## Build loop (per unit)

For each unit in dependency order:
1. Branch `ai/<KEY>-<slug>-u<n>` from the previous unit's branch (U1 from the base branch).
2. Tests first, confirm they fail for the right reason, then code until green.
3. Commit (with the trailer), run the sensors.
4. Review the unit's diff (`git diff <previous-branch>...HEAD`) with the code reviewers for
   the lane. Round caps apply per unit.
5. Record the unit in `state.json` (`status`, branch, sensor result, findings).

After the last unit, run `egm-code-spec-auditor` once on the cumulative diff
(`git diff <base>...HEAD`) to catch gaps between units. Do not repeat the other reviewers.

## MR strategy (`units.mr_strategy`)

- `stacked` (default for feature/high with more than one unit): one Draft MR per unit.
  MR 1 targets the base branch; MR n targets unit n-1's branch. Title
  `<KEY> [n/N]: <unit delivers>`. Each MR description lists the whole series and marks its
  own position. Retargeting after earlier MRs merge is the developer's job.
- `single`: one MR for the whole ticket, with the units listed in the description and one
  commit group per unit. Use for `small`, or when `units.mr_strategy: single`.

## Failure handling

- A unit that cannot go green within `loops.fix_max_attempts`: stop building. Open MRs for
  the completed units, mark the failed one `Draft` + `ai-needs-attention`, and PARK.
- Spec Deviation in unit n: amend the spec, re-check later units' assumptions, and note it
  in every MR from unit n onward.
- Never start unit n+1 on a red unit n.
