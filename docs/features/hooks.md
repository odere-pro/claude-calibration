# Hooks

Shell commands Claude Code runs in response to lifecycle events: `PreToolUse`, `PostToolUse`,
`Stop`, `UserPromptSubmit`, etc.

## Definition

- **Where declared** — `hooks` block in any `settings.json` (user/project/local), or a plugin's
  `hooks/hooks.json` referenced via `${CLAUDE_PLUGIN_ROOT}/hooks/...`.
- **What it does** — a `PreToolUse` hook with `exit 2` blocks the tool call; the stderr is
  surfaced back to Claude. `exit 0` lets the call through. `exit 1` is a non-blocking warning —
  using `exit 1` for what looks like enforcement is a common bug.

## Scope

User · Project · Plugin-shipped. Plugin hooks load for every user who enables the plugin — scope
them with a `matcher` and an `if` field, never bare `*`.

## Configure

- `matcher` should be narrow (`Edit|Write|MultiEdit` plus a path pattern), not `"*"`.
- Hook scripts should be local (`${CLAUDE_PROJECT_DIR}/...` or `${CLAUDE_PLUGIN_ROOT}/...`), not
  `curl | sh`.
- Use `exit 2` for blocking enforcement; `exit 0` for pass-through; `exit 1` only when you want a
  non-blocking warning.
- `PreToolUse`/`PostToolUse` must stay cheap — no `build`, `test`, `tsc`, `webpack` in a hook
  command.

## Validate

- `bash skills/calibrate-hooks/scripts/lint.sh <settings.json | hook-script.sh>` —
  `hook:matcher-bare-star`, `:exit-1-non-blocking`, `:remote-untrusted`,
  `:duplicate-across-layers`, `:not-locally-sourced`, `:heavy-on-pretooluse-heuristic`,
  `:invalid-json`.

## Improve

| Must                                | Should                                                | Limit                  |
| ----------------------------------- | ----------------------------------------------------- | ---------------------- |
| No `curl`/`wget` to remote URLs     | Narrow `matcher` (`Edit\|Write\|MultiEdit` + path)    | hook runs ≪ 1s         |
| No `exit 1` for enforcement         | Use `exit 2` to block, `exit 0` to pass               |                        |
| Valid JSON in the hooks block       | Local binaries via `${CLAUDE_PLUGIN_ROOT}` /          |                        |
|                                     | `${CLAUDE_PROJECT_DIR}`, not system PATH              |                        |

## Sources

- Hooks — <https://code.claude.com/docs/en/hooks>
