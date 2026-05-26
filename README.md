# claude-calibration

[![for Claude Code](https://img.shields.io/badge/for-Claude%20Code-d97757?logo=claude&logoColor=white)](https://code.claude.com/docs)
[![type](https://img.shields.io/badge/type-plugin-555)](https://github.com/odere-pro/claude-calibration)
[![status](https://img.shields.io/badge/status-pre--release-1f6feb)](https://github.com/odere-pro/claude-calibration/releases)
[![license](https://img.shields.io/badge/license-MIT-e3b341)](LICENSE)
[![gates](https://img.shields.io/github/actions/workflow/status/odere-pro/claude-calibration/ci.yml?branch=main&label=gates)](https://github.com/odere-pro/claude-calibration/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/odere-pro/claude-calibration/badge)](https://scorecard.dev/viewer/?uri=github.com/odere-pro/claude-calibration)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/12996/badge)](https://www.bestpractices.dev/projects/12996)

A Claude Code **plugin** that calibrates your setup — it runs an **evaluate → plan → calibrate →
re-evaluate** loop against a stated (or guessed) **intent**, produces a report, and — when the
intent calls for it — **scaffolds new config that stops the same issues recurring**.

## Install

In a Claude Code session, install from the marketplace:

```text
/plugin marketplace add odere-pro/claude-calibration
/plugin install claude-calibration@odere-pro
```

…or load a local checkout for one session (development):

```bash
claude --plugin-dir /path/to/claude-calibration
```

Full lifecycle — install / verify / update / uninstall — is in
[`docs/install.md`](docs/install.md).

## Commands

Every command is `disable-model-invocation: true` — Claude never auto-fires one; you invoke them by
name. The full matrix (modes, arguments, per-feature shortcuts) is in
[`docs/usage.md`](docs/usage.md).

| Command | What it does |
|---|---|
| `/calibrate "<goal>"` | **The orchestrator.** Start or resume a full run against your intent; with no goal it states a guessed one. Supports `status` / `restart` / `--yes`, plus built-in `tighten` / `harden` / `cost` modes. |
| `/claude-calibration:calibration` | **Dispatcher** — prints the menu, delegates to a flow, or forwards free text as the intent. |
| `/claude-calibration:calibration-audit` | Read-only baseline evaluation — no plan, no edits. Good as a CI gate. |
| `/claude-calibration:calibration-diff` | "What changed since the last run?" — re-evaluates against the previous baseline. |
| `/claude-calibration:calibration-track` | "Is calibration actually improving my setup?" — a deterministic snapshot compared vs a baseline anchored to the last PR merged onto `main` **and** vs the previous iteration. Independent of `/calibrate`'s built-in delta. |
| `/claude-calibration:calibration-flow` | "Does my *workflow* still behave?" — drives a multi-step workflow over a case set of golden fixtures and scores node recall/precision, edge handoff contracts, and flow intent. On-demand behavioural cross-check (non-deterministic); the verdict comes from a deterministic scorer. |
| `/claude-calibration:calibration-doctor` | ~5-second structural health check: JSON parses, hooks executable, frontmatter valid. |
| `/claude-calibration:calibration-onboarding` | First-time setup guide — detects your stack, recommends one next step. |
| `/claude-calibration:calibrate-<feature>` | Nine per-feature bundles you can run on their own: `skills`, `subagents`, `claude-md`, `rules`, `settings`, `hooks`, `mcp`, `plugins`, `general`. |

## How it works · why it's shaped this way

```text
your setup + a calibration goal
        │
        ▼
  pick a workflow:
    onboarding   first run — name the stack, suggest one step   (read-only)
    doctor       ~5-second structural health check              (read-only)
    audit        baseline evaluation — good CI gate             (read-only)
    diff         what changed since the last run                (read-only)
    calibrate    the full loop ▼

  plan ─► evaluate ─► approve ─► calibrate ─► re-evaluate ─► report
        │
        └─ recurring finding? ─► scaffold enforcement (hook · rule · wrapper skill)
```

`/calibrate` chains worker subagents — planner → evaluator (which fans out per-feature) → calibrator →
a delta re-evaluation — persisting state in `.claude/calibration/<run>/` so a run survives `/clear`.
Its highest-leverage move: when the same finding recurs, the planner stops emitting one-off fixes
and **scaffolds a feature that enforces the standard** (a hook, a path-scoped rule, a wrapper skill)
so the problem can't come back.

- **How** the loop runs end to end → [`docs/self-calibration.md`](docs/self-calibration.md)
- **Why** it's built as prose-for-agents that costs ~zero idle context →
  [`SOFTWARE-3-0.md`](SOFTWARE-3-0.md)
- **The doc-set** the evaluator grades against → [`docs/README.md`](docs/README.md)
- **Developing / contributing** — dev loop, gates, the signature contract →
  [`CONTRIBUTING.md`](CONTRIBUTING.md)

## Good to know

- **It edits your config.** Review the plan before approving. Project changes (`CLAUDE.md`,
  `.claude/**`, the repo's `.mcp.json`) are applied and easy to `git revert`; `~/.claude/**` changes
  are written up as recommendations for you to apply by hand.
- **Static audit, not the built-in diagnostics.** `/doctor`, `/context`, `/skills`, `/mcp` are
  CLI-only and can't be invoked by an agent. The evaluator *estimates* context cost from your files
  and asks you to paste those four outputs for the exact figures.
- Add `.claude/calibration/` to `.gitignore` unless you want runs committed (the calibrator offers
  to do this).

## License

MIT.
