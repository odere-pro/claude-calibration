---
name: plugin-dev
description: >-
  House rules for developing the claude-calibration plugin. Loads only when the open file is
  under .claude-plugin/, skills/calibrate-*/, skills/calibration*/, agents/calibration-*.md,
  hooks/, or rules/ — so the cost is bounded to plugin-internal edits.
paths:
  - ".claude-plugin/**"
  - "skills/calibrate-*/**"
  - "skills/calibration*/**"
  - "agents/calibration-*.md"
  - "hooks/**"
  - "rules/**"
---

# Plugin development — house rules

## Signature names are a contract

`rules/signatures.md` is the canonical catalogue. Every signature is `<feature>:<short-name>`,
lowercase, hyphenated.

- Never rename a signature in flight — older `eval-*.md` reports use the old name and the
  planner's cross-run recurrence detector will silently miss the match.
- When threshold-embedded (`over-200`, `over-400`) the threshold goes into the name; the planner
  groups the family by prefix.
- Adding a new signature needs **three** places in sync:
  1. A new row in `rules/signatures.md`.
  2. A new row in the owning bundle's `reference.md` ("Pattern signatures" section).
  3. An emit from the owning bundle's `scripts/lint.sh`.

A signature missing from any of those three is invisible somewhere in the pipeline.

## Dispatch map

`rules/dispatch.md` maps signature (or signature family) → bundle that owns the **fix**. The
calibrator reads this when applying improvement plan rows. If you add a new signature, decide
which bundle owns the fix (which may not be the bundle whose lint emitted it).

## Bundle layout

Every `skills/calibrate-<feature>/` ships:

```
SKILL.md          # frontmatter must include disable-model-invocation: true
reference.md      # Must / Should / Limits / Pattern signatures (lifted from signatures.md)
scripts/enumerate.sh   # list user + project + plugin-self instances (TSV: scope\tpath)
scripts/lint.sh        # emit TSV: path\tsignature\tseverity\tdetail
templates/<artifact>.tmpl   # at least one
examples/<case>/{before,after}.md   # at least one
```

`disable-model-invocation: true` is non-negotiable — Claude must never auto-fire a `calibrate-*`
bundle. The user fires them by name; the calibrator dispatches them.

## After editing

- Run `/reload-plugins` to pick up changes under `--plugin-dir`. New top-level `skills/`
  directories may need a full restart.
- Smoke-test with `/calibrate cost` (load-bearing on `calibrate-general/scripts/lint.sh`) and
  `/claude-calibration:calibration-audit` (read-only end-to-end).

## Hooks

`hooks/hooks.json` wires two `PreToolUse` write-guards. They MUST stay zero-cost when not firing:

- `calibrator-write-guard.sh` enforces the calibrator's allow-list only when
  `agent_type == calibration-calibrator`.
- `audit-write-guard.sh` enforces the run-folder-only contract only when the active run has
  `intent_source: audit-flow` in its `plan.md`.

If you extend the guards, preserve the early-exit-when-not-applicable behaviour.

## Don't

- Don't move components into `.claude-plugin/` — components live at the **plugin root**.
- Don't add unconditional rules under `rules/` — every rule MUST have `paths:` (this rule is itself
  proof of concept).
- Don't write a hook command that calls `curl`/`wget` or fetches a remote package on every fire.
