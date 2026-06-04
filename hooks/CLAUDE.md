# CLAUDE.md — `hooks`

## Scope

The plugin's two `PreToolUse` write-guards plus a `SessionStart` workflow installer, and their wiring.
They ship with the plugin; the guards protect the audited project from unintended writes during a
calibration run, and the installer makes the bundled `Workflow` script(s) runnable.

- `hooks.json` — wires both guards on `Edit|Write|MultiEdit` and the installer on `SessionStart`,
  using `${CLAUDE_PLUGIN_ROOT}`.
- `calibrator-write-guard.sh` — fires **only** when the active subagent is `calibration-calibrator`;
  blocks writes outside the calibrator's allow-list.
- `audit-write-guard.sh` — fires **only** during a `calibration-audit` run (`intent_source: audit-flow`);
  blocks writes outside the run folder (the read-only contract).
- `install-workflows.sh` — `SessionStart`; copies `../workflows/*.mjs` into the project's
  `.claude/workflows/` registry (so `/workflows` lists them). Idempotent and never clobbers local
  edits: copies when missing, silent when identical, warns when a present copy differs. Always
  `exit 0` (never blocks a session); no network.

## Invariants you must not break

- **Zero-cost when not applicable.** Each guard exits early and silently when its condition isn't met
  (wrong subagent / not an audit run). Preserve the early-exit; a guard that does work on every
  `Edit` taxes every session.
- **No network at fire time.** No `curl` / `wget` / remote `npx`. Enforced three ways: gate G12
  (`12-hooks-no-remote.sh`), the `hook:remote-untrusted` signature, and this repo's own
  `.claude/hooks/plugin-dev-guard.sh`.
- **Commands resolve.** Every `command` in `hooks.json` must point at an existing executable under
  `hooks/` (gate G13). Keep the `${CLAUDE_PLUGIN_ROOT}/hooks/...` form.
- **Blocking is `exit 2`.** Only exit code 2 blocks a tool call; `exit 1` is non-blocking (the
  `hook:exit-1-non-blocking` anti-pattern).

## Editing checklist

- [ ] Guard still early-exits when its condition is absent.
- [ ] No `curl`/`wget`/remote fetch added.
- [ ] `shellcheck -S error` clean (gate G8 lints `hooks/*.sh`).
- [ ] `bash tests/gates/run-all.sh` green (G12 + G13 cover this dir).

## How to test this area

- `bash tests/gates/12-hooks-no-remote.sh` and `bash tests/gates/13-hooks-json-resolves.sh`.
- `claude --plugin-dir .` → `/reload-plugins` → `/hooks` lists the two `claude-calibration` entries;
  `/claude-calibration:calibration-audit` exercises the audit guard.

## When in doubt

Hook semantics (matchers, exit codes, scoping) live in
[`../docs/features/hooks.md`](../docs/features/hooks.md); the house rule against remote fetches is in
[`../.claude/rules/plugin-dev.md`](../.claude/rules/plugin-dev.md).
