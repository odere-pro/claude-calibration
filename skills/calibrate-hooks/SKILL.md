---
name: calibrate-hooks
description: >-
  Audits and tunes hooks across user / project / plugin-shipped layers — both the `hooks` blocks
  inside any `settings.json` and standalone hook scripts under `.claude/hooks/` or a plugin's
  `hooks/`. Flags bare-`*` matchers on hot events (`PreToolUse`/`PostToolUse`/`UserPromptSubmit`),
  enforcement scripts that use `exit 1` (non-blocking warning) instead of `exit 2` (block), hook
  commands that `curl`/`wget`/`npx` remote payloads, heavy work (`build`/`test`/`tsc`/`webpack`)
  on hot events, hooks pointing to non-local binaries, duplicates across layers, and invalid
  JSON. Also scaffolds the `create` row when a recurring `subagent:missing-tools`,
  `skill:side-effecting-no-dmi`, `claude-md:must-rule-with-no-hook`, or `hook:exit-1-non-blocking`
  pattern needs a new enforcement hook. Invoked by the calibration orchestrator (`/calibrate`)
  and standalone via `/claude-calibration:calibrate-hooks`.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(bash *), Edit(.claude/hooks/**), Edit(~/.claude/hooks/**), Write(.claude/hooks/**), Write(~/.claude/hooks/**), Edit(.claude/settings.json), Write(.claude/settings.json)
---

# calibrate-hooks — per-feature bundle

You audit and tune hook configurations and hook scripts. Two entry points:

- **Direct invocation** (`/claude-calibration:calibrate-hooks`) — audit everything, report
  findings, propose fixes inline.
- **Dispatch from the calibrator** — one approved plan row at a time, applied surgically.

The workflow is the same; only the framing differs.

## 1. Enumerate

```bash
bash <BUNDLE>/scripts/enumerate.sh "$PROJECT_DIR"
```

Yields TSV `scope\tpath`. Scope is `settings` (a `settings.json` with a `hooks` block — user or
project), `script` (a project-local hook script under `.claude/hooks/`), `script-user` (user
hook script under `~/.claude/hooks/`), or `plugin-self` (when the project is itself a plugin and
ships hooks at `<plugin-root>/hooks/`).

## 2. Lint

```bash
bash <BUNDLE>/scripts/lint.sh <path …>
```

Yields TSV `path\tsignature\tseverity\tdetail`. The signatures this bundle owns
(see `reference.md`):

- `hook:matcher-bare-star` (MEDIUM)
- `hook:exit-1-non-blocking` (HIGH)
- `hook:remote-untrusted` (HIGH)
- `hook:duplicate-across-layers` (LOW) — only fires when multiple settings files are passed
- `hook:not-locally-sourced` (LOW)
- `hook:heavy-on-pretooluse-heuristic` (MEDIUM)
- `hook:invalid-json` (HIGH)

## 3. Fix — `kind: edit` rows

For each finding, the remediation pattern lives in `examples/<case>/`:

- `hook:matcher-bare-star` → `examples/matcher-bare-star/{before,after}.md`. Narrow the matcher
  to the specific tool(s) (`Edit|Write|MultiEdit`) plus a path pattern. Bare `*` on a hot event
  fires on every tool call.
- `hook:exit-1-non-blocking` → `examples/exit-1-non-blocking/{before,after}.md`. Replace `exit 1`
  with `exit 2` when the intent is to block; keep `exit 1` only for non-blocking warnings. The
  semantics: `exit 0` = pass, `exit 1` = non-blocking warning surfaced to the user, `exit 2` =
  block the tool call and surface stderr to Claude.
- `hook:remote-untrusted` → vendor the script locally under `${CLAUDE_PROJECT_DIR}/.claude/hooks/`
  or `${CLAUDE_PLUGIN_ROOT}/hooks/`. Hooks that `curl | sh` re-fetch on every fire and are a
  supply-chain risk.
- `hook:heavy-on-pretooluse-heuristic` → move the heavy work to a `Stop` hook (runs at session
  end) or a manual command. `PreToolUse`/`PostToolUse` must stay sub-second.
- `hook:not-locally-sourced` → point the command at `${CLAUDE_PROJECT_DIR}/...` or
  `${CLAUDE_PLUGIN_ROOT}/...` rather than relying on system `PATH`.
- `hook:duplicate-across-layers` → delete the duplicate from one layer (usually the user layer
  defers to project, or vice versa — keep the one closer to the change).
- `hook:invalid-json` → fix the JSON. Run `python3 -m json.tool <settings.json>` to find the
  parse error.

## 4. Create — `kind: create` rows

When the planner detects a recurrence that this bundle owns (per `rules/dispatch.md`):

- **`subagent:missing-tools` ×N** → scaffold a `PreToolUse` hook on `Edit(.claude/agents/*.md)`
  that fails (`exit 2`) when the edited file lacks `tools:` frontmatter. Use
  `templates/hooks.json.tmpl`.
- **`skill:side-effecting-no-dmi` ×N** → similar `PreToolUse` hook on
  `Edit(.claude/skills/*/SKILL.md)` requiring `disable-model-invocation: true` when the body
  contains side-effecting verbs. Use `templates/hooks.json.tmpl`.
- **`claude-md:must-rule-with-no-hook` ×N** → for each recurring "must"/"never" rule, scaffold
  the matching enforcement hook (a `PreToolUse` matcher that fails on the disallowed pattern).
  Use `templates/hooks.json.tmpl`.
- **`hook:exit-1-non-blocking` ×N** → companion `Stop` hook that lints
  `.claude/rules/hook-conventions.md` is in sync (the rule itself is created by
  `calibrate-rules`).

For each, copy `templates/hooks.json.tmpl`, fill in `{{matcher}}`, `{{command}}`,
`{{description}}`, and append the block to the right `settings.json` layer (project for
project-wide enforcement; plugin-shipped at `hooks/hooks.json` when the recurrence is across
many projects under a plugin author's control).

## 5. Verify

After every edit or create, re-run `bash <BUNDLE>/scripts/lint.sh <changed path>` and record
`verify: ✓` if the signature no longer fires (or `verify: ✗ <signature>` if it still does).

## Hard rules

- Never wire a hook that fetches a remote payload at fire time (`curl`/`wget`/`npx <remote>`).
  Vendor the script under `${CLAUDE_PROJECT_DIR}` or `${CLAUDE_PLUGIN_ROOT}`.
- Never use `exit 1` when the intent is to block — Claude treats it as a non-blocking warning.
- Never put `build`/`test`/`tsc`/`webpack`/`compile` on a `PreToolUse`/`PostToolUse` hook —
  defer to `Stop`.
- Preserve early-exit-when-not-applicable behaviour in any hook this bundle authors (zero-cost
  when the hook doesn't apply).
- Don't reformat unrelated content when applying a fix.
