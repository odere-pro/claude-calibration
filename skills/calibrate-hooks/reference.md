# Hooks calibration reference

> Source of truth: [`docs/features/hooks.md`](../../docs/features/hooks.md).

## Must

- No `curl`/`wget` or `npx <remote-package>` in a hook command — vendor the script under
  `${CLAUDE_PROJECT_DIR}/.claude/hooks/` or `${CLAUDE_PLUGIN_ROOT}/hooks/`.
- Valid JSON in every `settings.json` `hooks` block.
- Use `exit 2` to **block** a tool call; never `exit 1` for enforcement (`exit 1` is a
  non-blocking warning).
- Plugin-shipped hooks zero-cost when not firing — early-exit before doing any work.

## Should

- Narrow `matcher` (`Edit|Write|MultiEdit` + a path pattern), not bare `"*"` on hot events
  (`PreToolUse`/`PostToolUse`/`UserPromptSubmit`).
- Hook commands stay sub-second on `PreToolUse`/`PostToolUse`; defer `build`/`test`/`tsc`/
  `webpack` to `Stop` or a manual command.
- Reference local binaries via `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_ROOT}`, not system
  `PATH`.
- Avoid duplicating the same `(event, matcher, command)` across user and project layers.
- Use an `if` field to scope plugin-shipped hooks to the cases that actually need them.

## Limits

| Aspect | Recommended |
|---|---|
| Hot-event hook runtime | < 1s (`PreToolUse` / `PostToolUse` / `UserPromptSubmit`) |
| Matcher specificity | tool(s) + path pattern; never bare `*` on hot events |
| Exit codes | `0` pass · `1` non-blocking warning · `2` block |
| Source location | `${CLAUDE_PROJECT_DIR}` or `${CLAUDE_PLUGIN_ROOT}` only |

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `hook:matcher-bare-star` | `matcher: "*"` (or `""`/omitted) on a hot event (`PreToolUse` / `PostToolUse` / `UserPromptSubmit`) | MEDIUM |
| `hook:exit-1-non-blocking` | Hook script uses `exit 1` for what looks like enforcement (preceded by `BLOCKED`/`error` echo) | HIGH |
| `hook:remote-untrusted` | Hook command contains `curl`/`wget`/`npx ` followed by a URL or remote package | HIGH |
| `hook:duplicate-across-layers` | Same `(event, matcher, command)` defined in both user and project | LOW |
| `hook:not-locally-sourced` | Hook command references a binary not under `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_ROOT}` and not a known system tool | LOW |
| `hook:heavy-on-pretooluse-heuristic` | `PreToolUse`/`PostToolUse` command includes `build`/`test`/`compile`/`tsc`/`webpack` keywords | MEDIUM |
| `hook:invalid-json` | Settings `hooks` block doesn't parse | HIGH |
