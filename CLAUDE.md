# claude-calibration — plugin development

This repo is the source for the `claude-calibration` Claude Code plugin. It is **not** an
application — every file under here ships to end users when the plugin is installed.

## What ships

- `.claude-plugin/plugin.json` — manifest
- `skills/calibrate*/` — orchestrators + 9 per-feature bundles
- `agents/calibration-*.md` — 3 worker agents (planner, evaluator, calibrator)
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
