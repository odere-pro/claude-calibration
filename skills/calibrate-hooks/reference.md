# Hooks calibration reference

> Source of truth: [`docs/features/hooks.md`](../../docs/features/hooks.md).

## Must

- **Fast** — sub-second on tool events. Heavy work belongs on `Stop`.
- **Project-owned tooling.** Never run untrusted remote code from a hook (`curl | sh`, `npx <remote>`).
- **Exit code `2`** (or JSON `permissionDecision: deny`) for enforcement. `exit 1` is non-blocking.

## Should

- Scope `matcher` narrowly (`Edit|Write`, `Bash`, `mcp__server__.*`); use `if` for finer filtering
  (`Bash(git *)`, `Edit(*.ts)`).
- Order cheapest/most-local first: format → lint → type-check → build; reserve full builds for `Stop`.
- Idempotent + side-effect-safe (fires on every matching event, possibly many times a session).
- Add hooks in response to **observed, repeated pain** (the planner's recurrence detector promotes
  these). Don't pre-emptively over-hook.
- Single-digit hook count; periodic review with `/hooks`.

## Limits

| Aspect | Recommended |
|---|---|
| `PreToolUse`/`PostToolUse` runtime | < 1 s |
| `Stop` / build / verify hook runtime | < ~30–60 s |
| Hook count (across layers) | single digits |
| Enforcement exit code | **`2`** (or JSON deny) — never `1` |

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `hook:matcher-bare-star` | `matcher: "*"` (or `""` / omitted) on a hot event (`PreToolUse`/`PostToolUse`/`UserPromptSubmit`) | MEDIUM |
| `hook:exit-1-non-blocking` | Hook script uses `exit 1` for what looks like enforcement (preceded by `BLOCKED`/`error` echo) | HIGH |
| `hook:remote-untrusted` | Hook command contains `curl|wget|npx ` followed by a URL or remote package | HIGH |
| `hook:duplicate-across-layers` | Same `(event, matcher, command)` defined in both user and project | LOW |
| `hook:not-locally-sourced` | Hook command references a binary not in `${CLAUDE_PROJECT_DIR}` and not a system tool (`pnpm`, `git`, `node`, `python`, `bash`) | LOW |
| `hook:heavy-on-pretooluse-heuristic` | `PreToolUse`/`PostToolUse` hook command includes `build`/`test`/`compile`/`tsc`/`webpack` keywords (likely slow) | MEDIUM |
| `hook:invalid-json` | Settings `hooks` block doesn't parse | HIGH |
