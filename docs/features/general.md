# General (cross-cutting)

Findings that span more than one feature — context budget, layering hazards, missing-enforcement
patterns, and the diagnostics-ask reminder.

## Definition

- **Not a feature** — a synthesizer over all the other feature reports. The `Configure` and
  `Validate` sections below describe this bundle's own synthesis logic, not user-facing settings.
- **What it does** — rolls up "the standing context is too big across rules + CLAUDE.md", "this
  rule says 'always' but no hook enforces it", "managed setting silently overrides project value".

## Scope

Cross-cutting. Findings reference paths in other features; the bundle owns the synthesis logic
and the cost-mode lint.

## Configure

- Set the heuristic context-budget threshold in `scripts/lint.sh` (default ~5,000 tokens for
  always-on CLAUDE.md + unconditional rules).
- Always emit `general:diagnostics-ask` (INFO) so the evaluator's reports remind the user to paste
  `/doctor`, `/context all`, `/skills`, `/mcp` for exact numbers.

## Validate

- `bash skills/calibrate-general/scripts/lint.sh <project-dir>` — `general:context-budget-overflow`,
  `:nested-claude-md-conflict`, `:settings-precedence-surprise`,
  `:no-gitignore-for-claude-local`, `:must-rule-with-no-hook`, `:diagnostics-ask`.

## Improve

| Must                                | Should                                            | Limit                |
| ----------------------------------- | ------------------------------------------------- | -------------------- |
| `.gitignore` covers `CLAUDE.local.md`, | Keep standing context ≤ ~5,000 tokens          | ≤ 3 unindexed nested CLAUDE.md |
| `.claude/settings.local.json`,      | When "must"/"always"/"never" rules exist,         |                      |
| `.claude/calibration/`              | scaffold an enforcement hook                      |                      |

## Sources

- Overview — <https://code.claude.com/docs/en/overview>
- Memory — <https://code.claude.com/docs/en/memory>
