---
name: calibrate-settings
description: >-
  Audits and tunes every `settings.json` Claude Code reads — user (`~/.claude/settings.json`),
  user-local (`~/.claude/settings.local.json`), project (`.claude/settings.json`), project-local
  (`.claude/settings.local.json`), and plugin-self when the project is itself a plugin. Flags
  committed secrets, `--dangerously-skip-permissions` references, blanket-destructive
  `permissions.allow` entries (`Bash(*)`, `Bash(rm *)`, `Bash(sudo *)`), model pins in committed
  files, oversized `env` blocks, empty allow-lists (every prompt approved manually), invalid JSON,
  and project values silently overridden by managed policy. Also handles the `create` row when
  recurring `settings:permissions-empty` across projects calls for a baseline allow-list scaffold.
  Invoked by the calibration orchestrator (`/calibrate`) and standalone via
  `/claude-calibration:calibrate-settings`.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# calibrate-settings — per-feature bundle

You audit and tune `settings.json` files across every scope Claude Code reads. You receive one of
two kinds of work:

- **Direct invocation** (`/claude-calibration:calibrate-settings`) — audit everything, report
  findings, propose fixes inline. The user drives the conversation.
- **Dispatch from the calibrator** — one approved plan row at a time, applied surgically.

In both cases the workflow is the same; only the framing differs.

## 1. Enumerate

```bash
bash <BUNDLE>/scripts/enumerate.sh "$PROJECT_DIR"
```

Yields TSV `scope\tpath`. Scope is `user` (`~/.claude/settings.json`), `user-local`
(`~/.claude/settings.local.json`), `project` (`<PROJECT_DIR>/.claude/settings.json`),
`project-local` (`<PROJECT_DIR>/.claude/settings.local.json`), or `plugin-self`
(`<plugin-root>/.claude/settings.json` when the project is itself a plugin).

## 2. Lint

```bash
bash <BUNDLE>/scripts/lint.sh <path …>
```

Yields TSV `path\tsignature\tseverity\tdetail`. The signatures this bundle owns
(see `reference.md`):

- `settings:invalid-json` (HIGH)
- `settings:secret-in-committed` (CRITICAL)
- `settings:dangerously-skip-permissions` (CRITICAL)
- `settings:permissions-blanket-destructive` (HIGH)
- `settings:model-pinned-in-committed` (LOW)
- `settings:env-bloated` (LOW)
- `settings:permissions-empty` (LOW)
- `settings:precedence-surprise` (LOW)

## 3. Fix — `kind: edit` rows

For each finding, the remediation pattern is in `examples/<case>/`:

- `settings:secret-in-committed` → move the secret to `.local.json` (or an env-var reference);
  rotate the exposed credential.
- `settings:dangerously-skip-permissions` → remove the reference; if a workflow needed it, surface
  the underlying tool calls and add narrow `permissions.allow` entries instead.
- `settings:permissions-blanket-destructive` → replace `Bash(*)` / `Bash(rm *)` / `Bash(sudo *)`
  with the smallest set of narrow `Bash(<tool> *)` entries that covers real usage.
- `settings:model-pinned-in-committed` → move the `model:` pin to `.local.json` (per-machine) or
  drop it (let Claude pick).
- `settings:env-bloated` → move per-machine values to `.local.json`; keep committed `env` minimal.
- `settings:permissions-empty` → see `examples/permissions-empty/{before,after}.md`; copy the
  baseline allow-list from `templates/settings.json.tmpl`.
- `settings:invalid-json` → fix the parse error reported in the detail.
- `settings:precedence-surprise` → reconcile: either accept the managed override or surface the
  conflict to the policy owner.

## 4. Create — `kind: create` rows

When the planner detects a recurrence that this bundle owns (per `rules/dispatch.md`):

- **`settings:permissions-empty` ×N projects** → scaffold a baseline `.claude/settings.json` from
  `templates/settings.json.tmpl` — narrow read-only `Bash(...)` entries that are universally safe.

## 5. Verify

After every edit or create, re-run `bash <BUNDLE>/scripts/lint.sh <changed path>` and record
`verify: ✓` if the signature no longer fires (or `verify: ✗ <signature>` if it still does).

## Hard rules

- Never write a secret into a committed `settings.json`. If a secret is needed, the only correct
  place is `.local.json` (git-ignored) or an `${ENV_VAR}` reference.
- Never add `--dangerously-skip-permissions` to any settings layer.
- Don't widen `permissions.allow` beyond what the user explicitly approved — narrow entries only.
- Don't reformat unrelated keys in a settings file when applying a fix.
