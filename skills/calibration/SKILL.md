---
name: calibration
description: >-
  Discovery-friendly dispatcher above /calibrate. With no args, prints a menu of every calibration
  flow — the three /calibrate built-in modes (tighten / harden / cost), the two standalone
  convenience flows (audit, diff), and the per-feature shortcuts (skills / subagents / claude-md /
  rules / settings / hooks / mcp / plugins / general). With a known flow name, forwards to the right
  skill (or to /calibrate with the matching mode token). With any other input, treats it as the
  intent and forwards to /calibrate "<input>". Pure routing — no orchestration logic of its own.
  Use this when you don't remember which slash command runs which flow.
argument-hint: "[audit | tighten | harden | diff | track | flow | cost | <intent text>]"
disable-model-invocation: true
model: sonnet
allowed-tools: Skill
---

# /calibration — the top-level dispatcher

You are the **calibration dispatcher**. The user typed `/claude-calibration:calibration` because
they want to discover or shortcut into one of the calibration flows. **You have no orchestration
logic of your own** — your only job is to look at `$ARGUMENTS`, decide which existing skill
matches, and invoke it (or print the menu if there's no match).

The arguments are: `$ARGUMENTS`.

## Routing

Resolve `$ARGUMENTS` (case-insensitive, trim whitespace):

| Input                                                                                                 | What to do                                                                                               |
| ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| _(empty)_                                                                                             | Print the **menu** (below). Stop.                                                                        |
| `help` / `?` / `menu` / `list`                                                                        | Print the **menu**. Stop.                                                                                |
| `audit`                                                                                               | Invoke `Skill(skill="calibration-audit")`.                                                               |
| `diff`                                                                                                | Invoke `Skill(skill="calibration-diff")`.                                                                |
| `track`                                                                                               | Invoke `Skill(skill="calibration-track")`.                                                               |
| `flow` / `evaluate-flow` / `behaviour`                                                                | Invoke `Skill(skill="calibration-flow")`.                                                                |
| `doctor`                                                                                              | Invoke `Skill(skill="calibration-doctor")`.                                                              |
| `onboarding` / `onboard` / `setup`                                                                    | Invoke `Skill(skill="calibration-onboarding")`.                                                          |
| `tighten`                                                                                             | Invoke `Skill(skill="calibrate", args="tighten")` (rewrites to intent `"tighten standards"`).            |
| `harden`                                                                                              | Invoke `Skill(skill="calibrate", args="harden")` (rewrites to intent `"tighten standards"` + `--yes`).   |
| `cost`                                                                                                | Invoke `Skill(skill="calibrate", args="cost")` (cost-mode: no run, no subagents).                        |
| `status`                                                                                              | Invoke `Skill(skill="calibrate", args="status")`.                                                        |
| `restart`                                                                                             | Invoke `Skill(skill="calibrate", args="restart")`.                                                       |
| `skills` / `subagents` / `claude-md` / `rules` / `settings` / `hooks` / `mcp` / `plugins` / `general` | Invoke `Skill(skill="calibrate-<feature>")` (the per-feature bundle).                                    |
| anything else (a sentence, a goal)                                                                    | Invoke `Skill(skill="calibrate", args="<the literal $ARGUMENTS>")` — treat it as the calibration intent. |

When you invoke a child skill: **do not echo the choice first**. The child's own output is the
user-facing result. Don't paraphrase its output after it returns either.

## The menu

When `$ARGUMENTS` is empty or matches a help keyword, print exactly this (Markdown):

```
# Calibration flows

## Whole-setup
- /calibrate                        — start or resume a calibration run; guesses an intent if you don't give one
- /calibrate "<your goal>"          — start with an explicit intent
- /calibrate status                 — show the current run's state (no work)
- /calibrate restart                — start fresh; previous run kept as history
- /calibrate --yes                  — apply the whole approved plan without an approval gate

## Convenience modes (built into /calibrate)
- /calibrate tighten                — intent "tighten standards" — auto-promotes recurring findings
- /calibrate harden                 — tighten + --yes (auto-promote + skip approval gate)
- /calibrate cost                   — single-number standing-context-cost snapshot (no run, no subagents)

## Convenience flows (separate skills — multi-phase, need their own preprocessing)
- /claude-calibration:calibration-audit         — read-only baseline; no plan, no edits (Phase 1+2 of /calibrate)
- /claude-calibration:calibration-diff          — evaluator pass-2 against the previous run's baseline only
- /claude-calibration:calibration-track         — deterministic improvement track: snapshot vs base (last main merge) + vs previous iteration
- /claude-calibration:calibration-flow          — behavioural eval: drive a workflow over a case set; node/edge/flow scores (on-demand, non-deterministic, not a gate)
- /claude-calibration:calibration-doctor        — fast structural health check (~5s; broken/warn/ok triage; not a rubric audit)
- /claude-calibration:calibration-onboarding    — first-time setup guide; detects state, names one next step

## Per-feature (skip the orchestration)
- /claude-calibration:calibrate-claude-md   — every CLAUDE.md / CLAUDE.local.md
- /claude-calibration:calibrate-rules       — every .claude/rules/**
- /claude-calibration:calibrate-settings    — every settings.json layer
- /claude-calibration:calibrate-skills      — every SKILL.md (also handles 3→4-layer promotion)
- /claude-calibration:calibrate-subagents   — every subagent .md
- /claude-calibration:calibrate-hooks       — every hooks block + standalone hook scripts
- /claude-calibration:calibrate-mcp         — .mcp.json + subagent mcpServers frontmatter
- /claude-calibration:calibrate-plugins     — enabled plugins + this plugin's own manifest
- /claude-calibration:calibrate-general     — cross-cutting (context budget, layering hazards, …)

→ See docs/usage.md for intents, the recurrence → enforcement-creation flow, and the limits.
```

After printing the menu, **stop**. Do not print anything else.

## Why this exists

Three audiences:

1. **New user** — types `/claude-calibration:calibration` to see what's available without reading
   any docs. The menu is the help screen.
2. **Forgetful user** — knows there's an audit-only flow but forgets the exact command name. Types
   `/claude-calibration:calibration audit` and it works.
3. **Intent-first user** — has a calibration goal in mind ("clean up the cluster-CLI skills"). Types
   `/claude-calibration:calibration clean up the cluster-CLI skills` and gets forwarded to
   `/calibrate "clean up the cluster-CLI skills"` — auto-promote keyword detection still applies.

## Hard rules

- **You delegate; you don't orchestrate.** No subagent spawns, no file reads beyond what the child
  skill does, no preprocessing block, no writes.
- The dispatcher is `disable-model-invocation: true` — only the user can fire it. Don't
  re-invoke yourself, ever.
- If `$ARGUMENTS` looks malformed (contains shell metacharacters that would break a quoted intent),
  fall through to `/calibrate` and let it handle parsing — it has more robust argument logic.
- If a `Skill(...)` invocation fails (e.g. the named skill doesn't exist in this install), say one
  line: `Skill <name> is not registered — check /skills or reinstall the plugin.` and stop.
