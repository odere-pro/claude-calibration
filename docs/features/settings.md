# Settings

The `settings.json` files that configure permissions, environment, hooks, model, and other harness
controls.

## Definition

- **Files** — `~/.claude/settings.json` (user), `.claude/settings.json` (project, committed),
  `.claude/settings.local.json` (project, git-ignored), managed enterprise policy paths.
- **What it does** — declares allowed tools/commands (`permissions.allow`), environment variables
  (`env`), hook bindings (`hooks`), default model (`model`), status line, etc.

## Scope

User · Project · Local · Managed. Precedence (lowest → highest): user → project → local →
managed.

## Configure

- JSON. `permissions.allow` is an array of tool specs (`Bash(git *)`, `Read`, `Edit(.claude/**)`).
- Secrets and machine-local overrides belong in `.local.json` (git-ignored), not the committed
  `settings.json`.
- Never reference `--dangerously-skip-permissions`.

## Validate

- `/config` shows the merged effective settings.
- `bash skills/calibrate-settings/scripts/lint.sh <settings.json>` — emits
  `settings:secret-in-committed`, `:dangerously-skip-permissions`,
  `:permissions-blanket-destructive`, `:model-pinned-in-committed`, `:env-bloated`,
  `:permissions-empty`, `:invalid-json`, `:precedence-surprise`.

## Improve

| Must                                  | Should                                              | Limit                |
| ------------------------------------- | --------------------------------------------------- | -------------------- |
| No secrets in committed file          | Narrow `permissions.allow` entries (no `Bash(*)`)   | `env` < ~10 entries  |
| No `--dangerously-skip-permissions`   | Move secrets and personal overrides to `.local`     |                      |
| Valid JSON                            | Don't pin `model:` in committed settings            |                      |

## Sources

- Settings — <https://code.claude.com/docs/en/settings>
