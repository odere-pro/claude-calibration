# claude-calibration — plugin development

This repo is the source for the `claude-calibration` Claude Code plugin. It is **not** an
application — every file under here ships to end users when the plugin is installed.

## What ships

- `.claude-plugin/plugin.json` — manifest
- `skills/calibrate*/` — orchestrators + 9 per-feature bundles
- `skills/calibration-*/` — top-level flows: `calibration` (dispatcher), `calibration-audit`,
  `calibration-diff`, `calibration-doctor`, `calibration-onboarding`
- `agents/calibration-*.md` — 4 worker agents: planner, evaluator, calibrator, and
  `calibration-feature-evaluator` (haiku worker the evaluator fans out to in parallel)
- `rules/{signatures,dispatch}.md` — canonical signature catalogue + dispatch map
- `hooks/{hooks.json,calibrator-write-guard.sh,audit-write-guard.sh}` — `PreToolUse` write-guards
- `docs/` — human-readable rubric (the doc-set the plugin grades against)

## What doesn't

- `.claude/` (this dir's project config — only for plugin authors, not shipped)
- `tmp/` (scratch)
- `.claude/calibration/` (run artifacts)

## Pointers

- README for the user-facing pitch: [`README.md`](README.md)
- Docs index (the rubric): [`docs/README.md`](docs/README.md)
- Plugin lifecycle & usage: [`docs/install.md`](docs/install.md), [`docs/usage.md`](docs/usage.md)

## House rules

Detailed plugin-development rules live in `.claude/rules/plugin-dev.md` (path-scoped to plugin
internals; loads on-demand).

Do **not**:

<!-- TODO: add PreToolUse hook on rules/signatures.md and rules/dispatch.md to enforce the two hard rules below (see enforcement opportunity E3 in the calibration plan) -->
- rename a pattern signature (breaks recurrence history — see `rules/signatures.md`).
- break the `signature → bundle` map in `rules/dispatch.md`.
- skip `/reload-plugins` after editing under `--plugin-dir`.

Run the plugin against itself to validate changes:

```bash
cd /Users/aleksandrderechei/Git/claude-calibration
claude --plugin-dir .
# then in the session:
/reload-plugins
/claude-calibration:calibration-audit
```
