# Security policy

`claude-calibration` audits and edits Claude Code configuration. It ships no network code and no
compiled binaries; its only moving parts are Markdown instructions and a few Bash scripts.

## Trust model

The plugin is designed so that its one privileged action — the calibrator editing your config — is
fenced by deterministic guards, and so that nothing it ships reaches the network.

- **Two `PreToolUse` write-guards** (`hooks/hooks.json` → `hooks/*.sh`) gate every `Edit`/`Write`/
  `MultiEdit`:
  - `calibrator-write-guard.sh` fires **only** when the active subagent is `calibration-calibrator`,
    and blocks any write outside an allow-list: the project `CLAUDE.md` / `CLAUDE.local.md`, the
    project `.claude/**`, `.mcp.json`, `AGENTS.md`, `.gitignore`, the plugin-self component dirs when
    a `.claude-plugin/plugin.json` is present, and the explicit paths named in the approved plan.
  - `audit-write-guard.sh` fires **only** during a `/claude-calibration:calibration-audit` run
    (`intent_source: audit-flow`) and blocks any write outside that run's folder — enforcing the
    audit flow's read-only contract.
  - Both exit early and silently when not applicable (zero standing cost).
- **No network at routing time.** No shipped hook calls `curl` / `wget` or fetches a remote package;
  gate `G12` (`tests/gates/12-hooks-no-remote.sh`) enforces this.
- **User-scope changes are recommended, not applied.** Edits to `~/.claude/**` are written up as
  recommendations; only project-scope config is changed automatically (and Claude Code prompts on
  out-of-repo writes regardless).
- **Approval gate.** `/calibrate` shows the plan and waits for approval unless you pass `--yes`.

## In scope

- The calibrator writing outside its allow-list when acting as `calibration-calibrator`.
- A shipped skill, agent, rule, or hook leaking a secret or fetching untrusted remote content.
- A way to bypass either write-guard's early-exit / allow-list logic.

## Out of scope

- Changes you explicitly approve in a calibration plan, or run with `/calibrate --yes`.
- Edits you make by hand to your own `~/.claude/**` after the plugin recommends them.
- The behaviour of *other* tools the plugin merely audits.

## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.1.x   | ✅        |
| < 0.1   | ❌        |

## Reporting a vulnerability

Please report privately via **GitHub Security Advisories** —
<https://github.com/odere-pro/claude-calibration/security/advisories/new> — rather than opening a
public issue. You can also reach the maintainer at <odere.pro@gmail.com>. We aim to acknowledge
within a few days and to fix or mitigate confirmed issues before any public disclosure.
