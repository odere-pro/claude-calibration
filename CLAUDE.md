# claude-calibration — plugin development

This repo is the source for the `claude-calibration` Claude Code plugin. It is **not** an
application — every file under here ships to end users when the plugin is installed.

## What ships

- `.claude-plugin/plugin.json` — manifest (version of record)
- `.claude-plugin/marketplace.json` — single-plugin marketplace manifest (`source: "./"`); version
  is omitted here on purpose — `plugin.json` wins
- `skills/calibrate*/` — orchestrators + 9 per-feature bundles
- `skills/calibration-*/` — top-level flows: `calibration` (dispatcher), `calibration-audit`,
  `calibration-diff`, `calibration-doctor`, `calibration-onboarding`
- `agents/calibration-*.md` — 4 worker agents: planner, evaluator, calibrator, and
  `calibration-feature-evaluator` (haiku worker the evaluator fans out to in parallel)
- `rules/{signatures,dispatch}.md` — canonical signature catalogue + dispatch map
- `hooks/{hooks.json,calibrator-write-guard.sh,audit-write-guard.sh}` — `PreToolUse` write-guards
- `docs/` — human-readable rubric (the doc-set the plugin grades against)

## What doesn't

- `.claude/` (this dir's project config — only for plugin authors, not loaded for end users)
- `tmp/` (scratch)
- `.claude/calibration/` (run artifacts)

> Note: Claude Code clones the **whole** repo into the plugin cache — there is no ship-whitelist or
> `.claudeignore`. So author-only files (`.claude/`, `tests/gates/`, `.github/`, `CONTRIBUTING.md`,
> `SECURITY.md`, `CHANGELOG.md`, `SOFTWARE-3-0.md`, …) are copied but never *loaded* — Claude only
> loads recognized component dirs (`skills/`, `agents/`, `rules/`, `hooks/`, `commands/`) plus the
> manifest. They cost nothing at runtime, so we don't add a build/packaging step to strip them.

## Pointers

- README for the user-facing pitch: [`README.md`](README.md)
- Docs index (the rubric): [`docs/README.md`](docs/README.md)
- Plugin lifecycle & usage: [`docs/install.md`](docs/install.md), [`docs/usage.md`](docs/usage.md)

## Agent routing

The 4 worker agents (`calibration-planner`, `calibration-evaluator`, `calibration-calibrator`,
`calibration-feature-evaluator`) are invoked exclusively by the orchestrator skill at
`skills/calibration/SKILL.md`. No root `AGENTS.md` is needed; routing is encoded in the
orchestrator's dispatch logic, not a routing table.

## House rules

Detailed plugin-development rules live in `.claude/rules/plugin-dev.md` (path-scoped to plugin
internals; loads on-demand).

Guard rails (each labelled by enforcement mechanism):

- **[signature-tracked]** Don't rename a pattern signature — breaks recurrence history. See
  `rules/signatures.md`; signature `rule:should-be-skill` tracks this class of violation.
- **[hook-guarded]** Don't break the `signature → bundle` map in `rules/dispatch.md` —
  signature `general:must-rule-with-no-hook` flags it and `hooks/calibrator-write-guard.sh`
  blocks unauthorised writes during a calibrator session.
- **[advisory]** Don't skip `/reload-plugins` after editing under `--plugin-dir`. No hook
  enforces this; it's a workflow reminder.

Run the plugin against itself to validate changes:

```bash
cd $PROJECT_DIR
claude --plugin-dir .
# then in the session:
/reload-plugins
/claude-calibration:calibration-audit
```
