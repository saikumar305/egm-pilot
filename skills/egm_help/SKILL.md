---
name: egm-help
license: Apache-2.0
disable-model-invocation: true
description: >-
  Shows how to use EGM Pilot: every skill, what it is for, its arguments and examples,
  and the common paths through them. Use with no arguments for the overview, or with a
  skill name (for example autopilot) for that skill's details.
---

# EGM Help

Usage: `/egm-pilot:egm-help [skill]`

Read `${CLAUDE_PLUGIN_ROOT}/skills/egm_help/references/help.md`. It is the only source:
do not add, reword or summarize, and do not read other files.

- **No arguments:** print the `## overview` section.
- **A skill name:** add the `egm-` prefix if it is missing (`autopilot` becomes
  `egm-autopilot`) and print that `##` section. If no section matches, say so and print
  the overview.
- **`all`:** print every section in order.

Print the section body in a `text` code block, without its `##` heading. Do not start any
other work.
