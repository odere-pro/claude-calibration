# CLAUDE.md — `agents`

## Scope

The four **worker subagents** the orchestrator dispatches. They ship with the plugin and are invoked
**only** by the skill layer — never by the user directly, never auto-fired.

- `calibration-planner.md` (opus) — writes `plan.md`; init mode (skeleton) + improve mode (recurrence
  detection → enforcement-creation rows).
- `calibration-evaluator.md` (sonnet) — audits the setup against the rubric; Pass 1 (baseline) +
  Pass 2 (delta); fans out the feature workers.
- `calibration-feature-evaluator.md` (haiku) — audits ONE feature; the evaluator spawns nine in
  parallel, one per feature.
- `calibration-calibrator.md` (sonnet) — applies approved plan rows, dispatching through each
  bundle's templates/examples.

## Map

```
/calibrate (orchestrator)
   ├─ calibration-planner        (init, then improve)
   ├─ calibration-evaluator      ──▶ 9× calibration-feature-evaluator (parallel, one per feature)
   └─ calibration-calibrator     (walks the approved plan)
```

Routing is encoded in the orchestrator's dispatch logic (`../skills/calibration/SKILL.md` and
`../skills/calibrate/SKILL.md`), not a routing table — no root `AGENTS.md` is needed.

## Invariants you must not break

- **Frontmatter shape**: every subagent declares `name`, `description`, `tools`, `model` (gate G5).
  Omitting `tools` would inherit every tool incl. MCP — the `subagent:missing-tools` anti-pattern.
- **Model tiering**: workers are haiku/sonnet; only the planner is opus. The feature-evaluator stays
  haiku (cheap parallel fan-out).
- **Invocation boundary**: only the skill layer spawns these. The feature-evaluator is spawned only
  by the evaluator, never by the orchestrator directly.
- **The write-guards apply**: when `calibration-calibrator` is active, `hooks/calibrator-write-guard.sh`
  fences its writes to the allow-list. Don't widen a subagent's reach past what the guard expects.

## Editing checklist

- [ ] `name`/`description`/`tools`/`model` all present and `tools` is explicit (not omitted).
- [ ] Description carries routing cues so the orchestrator dispatches correctly.
- [ ] `bash tests/gates/05-agent-frontmatter.sh` green.

## How to test this area

- `bash tests/gates/05-agent-frontmatter.sh` — frontmatter completeness.
- `claude --plugin-dir .` → `/reload-plugins` → `/calibrate "audit this plugin's setup"` exercises
  the full planner → evaluator → calibrator chain.

## When in doubt

The recurrence → enforcement archetypes the planner emits live in
[`../rules/dispatch.md`](../rules/dispatch.md); the bundle layer they dispatch into is
[`../skills/CLAUDE.md`](../skills/CLAUDE.md).
