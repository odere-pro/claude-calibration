---
name: dispatch
description: >-
  The signature -> bundle dispatch table. Used by the calibrator when routing an approved row to its
  per-feature bundle, and by the planner when emitting `bundle:` on each improvement-plan row.
  Loads only when you have a calibrate-* bundle directory or a calibration agent file open, so the
  cost is bounded. Keeps the routing logic in one place — a missing entry here means the calibrator
  has to guess.
paths:
  - "skills/calibrate-*/**"
  - "skills/calibration-*/**"
  - "agents/calibration-*.md"
---

# Bundle dispatch — signature → bundle

When the planner builds an improvement-plan row, it sets `bundle: <calibrate-feature>` so the
calibrator knows which bundle's `SKILL.md`, `templates/`, `examples/`, and `scripts/lint.sh` to
use. This file is the canonical map. See [`signatures.md`](signatures.md) for the signature
catalogue itself.

## Edit-row dispatch (one-off fixes)

For `kind: edit` rows, the bundle is the feature the file lives in:

| File pattern                                                                                     | Bundle                |
| ------------------------------------------------------------------------------------------------ | --------------------- |
| `CLAUDE.md`, `CLAUDE.local.md`, nested `**/CLAUDE.md`                                            | `calibrate-claude-md` |
| `.claude/rules/**/*.md`, `~/.claude/rules/**/*.md`                                               | `calibrate-rules`     |
| `.claude/settings.json`, `.claude/settings.local.json`, `~/.claude/settings.json`                | `calibrate-settings`  |
| `.claude/skills/<name>/SKILL.md`, `.claude/commands/*.md`, `~/.claude/skills/<name>/SKILL.md`    | `calibrate-skills`    |
| `.claude/agents/*.md`, `~/.claude/agents/*.md`                                                   | `calibrate-subagents` |
| `.claude/hooks/**`, the `hooks` block inside any settings.json                                   | `calibrate-hooks`     |
| `.mcp.json`, `~/.claude.json` `mcpServers` block, agent `mcpServers:` frontmatter                | `calibrate-mcp`       |
| `.claude-plugin/plugin.json`, `installed_plugins.json`, `known_marketplaces.json`                | `calibrate-plugins`   |
| `.gitignore` (only for `.claude/calibration/`), `.claude/settings.local.json` `claudeMdExcludes` | `calibrate-general`   |

## Create-row dispatch (recurrence → enforcement)

When the planner detects a recurrence (signature firing ≥3× in this run or ≥2× across older runs)
it emits a `kind: create` row alongside the per-instance `edit` rows. The recurrence archetype
table:

| Recurring signature                           | Create-row bundle                     | Template the calibrator uses                                                                                                              |
| --------------------------------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `subagent:missing-tools` (×N)                 | `calibrate-hooks`                     | a `PreToolUse` hook on `Edit(.claude/agents/*.md)` failing if `tools:` is absent (uses `calibrate-hooks/templates/hooks.json.tmpl`)       |
| `skill:side-effecting-no-dmi` (×N)            | `calibrate-hooks`                     | similar hook on `Edit(.claude/skills/*/SKILL.md)`                                                                                         |
| `claude-md:vague-rules` (×N)                  | `calibrate-rules`                     | a path-scoped rule in `.claude/rules/conventions.md` listing the canonical wordings (uses `calibrate-rules/templates/rule.md.tmpl`)       |
| `claude-md:must-rule-with-no-hook` (×N)       | `calibrate-hooks`                     | the matching enforcement hook for the recurring "must" rule (uses `calibrate-hooks/templates/hooks.json.tmpl`)                            |
| `skill:cli-not-wrapped` (×N for the same CLI) | `calibrate-skills`                    | **3→4-layer promotion** — wrapper skill via `calibrate-skills/templates/cli-wrapper.tmpl`                                                 |
| `mcp:no-skill-pair` (×N for the same server)  | `calibrate-skills`                    | wrapper skill via `calibrate-skills/templates/mcp-wrapper.tmpl`                                                                           |
| `hook:exit-1-non-blocking` (×N)               | `calibrate-rules` + `calibrate-hooks` | a doc-rule in `.claude/rules/hook-conventions.md` AND a `Stop` hook that lints the rule (two `create` rows, planner's choice on ordering) |
| `settings:permissions-empty` (×N projects)    | `calibrate-settings`                  | a baseline `permissions.allow` block via `calibrate-settings/templates/settings.json.tmpl`                                                |
| `general:must-rule-with-no-hook`              | `calibrate-hooks`                     | rolled-up version of the per-feature one — the planner usually emits one or the other, not both                                           |

## Cross-bundle hand-offs

Some `edit`-row findings produce work in _two_ bundles:

| Edit-row signature                                  | Primary bundle                                              | Companion work                                                              |
| --------------------------------------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------- |
| `claude-md:over-200` / `claude-md:over-400`         | `calibrate-claude-md` (trim)                                | `calibrate-rules` (the moved-out block becomes a new path-scoped rule file) |
| `subagent:bare-mcp-in-mcpjson`                      | `calibrate-subagents` (move into `mcpServers:` frontmatter) | `calibrate-mcp` (remove the entry from `.mcp.json`)                         |
| `mcp:subagent-only-in-shared`                       | `calibrate-mcp` (remove from shared `.mcp.json`)            | `calibrate-subagents` (add to that agent's `mcpServers:` frontmatter)       |
| `skill:cli-not-wrapped` (one-off, _not_ recurrence) | `calibrate-skills` (note the candidate)                     | nothing — only the recurrence triggers a `create` row                       |

The calibrator handles companion work as a _single plan row_ — the primary bundle's workflow knows
to update the companion file. Don't split into two rows or the user has to approve twice for what's
conceptually one fix.

## Bundle ownership of pattern signatures

Every signature belongs to exactly one bundle (which owns its `lint.sh`). Cross-references go via
`general:` rollups (e.g. `general:must-rule-with-no-hook` is the cross-feature rollup of
`claude-md:must-rule-with-no-hook` and rule-level "must" findings):

| Prefix        | Owning bundle                                                      |
| ------------- | ------------------------------------------------------------------ |
| `claude-md:*` | `calibrate-claude-md`                                              |
| `rule:*`      | `calibrate-rules`                                                  |
| `settings:*`  | `calibrate-settings`                                               |
| `skill:*`     | `calibrate-skills`                                                 |
| `subagent:*`  | `calibrate-subagents`                                              |
| `hook:*`      | `calibrate-hooks`                                                  |
| `mcp:*`       | `calibrate-mcp`                                                    |
| `plugin:*`    | `calibrate-plugins`                                                |
| `general:*`   | `calibrate-general` (cross-cutting; rolls up per-feature findings) |

## When a new dispatch rule is needed

1. Decide which bundle owns the _fix_ (not necessarily the bundle whose lint emitted the signature
   — a `claude-md:` finding can resolve via a `calibrate-rules` edit when the right answer is "move
   this into a path-scoped rule").
2. Add the row to the appropriate table above.
3. Make sure the owning bundle's `SKILL.md` workflow knows how to handle the companion work, if any.
4. If it's a recurrence archetype, also note it in the planner's improve-mode body
   (`agents/calibration-planner.md`) — that's the primary place the recurrence detector reads the
   archetype table; this file is the rationalised cross-bundle view.
