# General calibration reference

> Source of truth: [`docs/features/general.md`](../../docs/features/general.md).

## Must

- `.gitignore` covers `CLAUDE.local.md`, `.claude/settings.local.json`, `.claude/calibration/`.
- The lint always emits `general:diagnostics-ask` (INFO) so users are reminded to paste the four
  CLI outputs (`/doctor`, `/context all`, `/skills` press `t`, `/mcp`) for exact numbers.

## Should

- Keep the always-on standing context (CLAUDE.md + unconditional `.claude/rules/*.md`) ≤ ~5,000
  tokens.
- Add `paths:` frontmatter to every language- or directory-specific rule so it loads on demand.
- When CLAUDE.md or a rule says "always"/"never"/"must", back it with a hook — otherwise it's
  hope, not enforcement.

## Limits

| Aspect                    | Recommended                       |
| ------------------------- | --------------------------------- |
| Standing context cost     | ≤ ~5,000 tokens                   |
| Nested CLAUDE.md files    | ≤ 3 below project root            |
| "Must"-shaped lines       | each backed by a hook             |

## Pattern signatures

| Signature                               | Trigger                                                                                       | Default severity |
| --------------------------------------- | --------------------------------------------------------------------------------------------- | ---------------- |
| `general:context-budget-overflow`       | Estimated always-on cost > ~5,000 tokens                                                      | MEDIUM           |
| `general:must-rule-with-no-hook`        | CLAUDE.md or rules contain "always"/"never"/"must" lines but no hooks block exists            | MEDIUM           |
| `general:nested-claude-md-conflict`     | ≥ 3 nested CLAUDE.md the root CLAUDE.md does not index by path (undocumented layering)         | LOW              |
| `general:settings-precedence-surprise`  | A project setting is silently overridden by a managed setting                                 | LOW              |
| `general:no-gitignore-for-claude-local` | `.gitignore` doesn't cover `CLAUDE.local.md` / `.claude/settings.local.json` / `.claude/calibration/` | LOW       |
| `general:diagnostics-ask`               | (Always emitted) Reminder that the four CLI outputs should be pasted into the report          | INFO             |
