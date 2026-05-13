# claude-calibration

A Claude Code **plugin** that calibrates your setup — runs an **evaluate → plan → calibrate →
re-evaluate** loop against a stated/guessed **calibration intent**, produces a final report, and (when
the intent calls for it) **scaffolds new features into your setup** that prevent the same issues
recurring.

## Architecture — three layers

```
                              entry point (top)
                /calibration (dispatcher) → /calibrate (orchestrator, opus)
                                            └── built-in modes: tighten · harden · cost
                /claude-calibration:calibration-{audit,diff}  (separate skills — multi-phase)
                                    │ chains
                                    ▼
                                  agents (middle)
       calibration-planner (opus) · calibration-evaluator (sonnet) · calibration-calibrator (sonnet)
                                    │ dispatch per-feature work
                                    ▼
                                  skills (bottom — per-feature calibration toolkits)
       calibrate-{claude-md, rules, settings, skills, subagents, hooks, mcp, plugins, general}
       each bundle ships:  SKILL.md  reference.md  templates/  examples/  scripts/
                            (disable-model-invocation: true → zero standing context)
                                    │ supported by
                                    ▼
                            rules/ (path-scoped — load only on calibration files)
                            hooks/ (PreToolUse write-guards — zero cost unless they fire)
```

Three layers, plus a fourth when the work integrates an external system: **CLI / MCP → skills → agents
→ entry point**. The evaluator detects which pattern each capability uses (3 or 4) and grades against
the right rubric — a heavy CLI-shelling skill that's "3-layer" is leaving capability on the table; an
MCP server with no wrapper skill is the docs' own anti-pattern.

## What's in this repo

| Path | What |
|---|---|
| `docs/` | The source rubric — a doc-set grounded in the official Claude Code docs (`code.claude.com/docs/*`). One page per feature with **Configure / Validate / Improve** sections + a `## Sources` block. Start at [`docs/README.md`](docs/README.md). Plugin walkthroughs live in [`docs/install.md`](docs/install.md) and [`docs/usage.md`](docs/usage.md). |
| `.claude-plugin/plugin.json` | Plugin manifest (`v0.2.0`). |
| `skills/calibrate/` | The orchestrator — `/calibrate`. |
| `skills/calibration/` | The top-level dispatcher — `/claude-calibration:calibration` (menu / shortcut / intent forwarder above `/calibrate`). |
| `skills/calibration-{audit,diff}/` × 2 | Convenience flow skills — slim orchestrators that spawn their own subagent chain (`disable-model-invocation: true`). The three other shortcuts — `tighten`, `harden`, `cost` — are argument-token modes inside `/calibrate` rather than separate skills. |
| `skills/calibrate-<feature>/` × 9 | The per-feature calibration bundles. Each is also user-invocable on its own (e.g. `/claude-calibration:calibrate-skills`). |
| `agents/` | The 3 worker subagents: `calibration-planner`, `calibration-evaluator`, `calibration-calibrator`. |
| `rules/` | Two path-scoped rules (`signatures.md`, `dispatch.md`) — the canonical signature catalogue and the signature → bundle map. `paths:` frontmatter limits them to calibration files, so they cost zero standing context. |
| `hooks/` | Two `PreToolUse` write-guards: `calibrator-write-guard.sh` enforces the calibrator's allow-list at the tool-call layer; `audit-write-guard.sh` keeps `/claude-calibration:calibration-audit` read-only. Zero cost unless they fire. |
| `.claude/` | This repo's **own** setup — including `/docs-status`, `/docs-update`, `/plugin-update` for keeping `docs/` and the plugin's own bundles in sync with the official docs. Not shipped. |

## Use it

In a Claude Code session:

```bash
claude --plugin-dir /path/to/claude-calibration
```

…or install via `/plugin`. Full lifecycle (install / verify / update / uninstall) is in
[**`docs/install.md`**](docs/install.md); a walkthrough of every flow (intents, recurrence →
enforcement-creation, per-feature shortcuts, reading the run-folder files) is in
[**`docs/usage.md`**](docs/usage.md).

Pick the level of fidelity you need:

### Discovery (the dispatcher)

| Command | What it does |
|---|---|
| `/claude-calibration:calibration` | Top-level dispatcher — with no args prints the menu of every flow; with a flow name (`audit` / `tighten` / `harden` / `diff` / `cost`) delegates to it; with any other input treats it as the calibration intent and forwards to `/calibrate "<input>"`. |

### Whole-setup calibration (the orchestrator)

| Command | What it does |
|---|---|
| `/calibrate` | Start a new run, or **resume** an in-progress one. With no stored/given intent it states a **guessed** intent and proceeds. |
| `/calibrate "<your goal>"` | Set the intent (e.g. `"reduce always-on context cost"`, `"tighten standards"`, `"make the TDD loop reliable"`). |
| `/calibrate --yes` | Skip the approval gate (apply all planned changes). |
| `/calibrate status` | Show the current run's state — intent, phase, severity counts, what was touched. |
| `/calibrate restart` | Start a fresh run (the previous run's folder is kept as history). |

### Convenience modes (built into `/calibrate`)

These are argument tokens recognised by `/calibrate`'s parser — no separate skills:

| Command | What it does |
|---|---|
| `/calibrate tighten` | Rewrites to intent `"tighten standards"` — pre-fills the auto-promote keyword (recurring findings become `kind: create` rows). |
| `/calibrate harden` | Rewrites to `"tighten standards" --yes` — auto-promote + skip approval. Guarded by the calibrator-write-guard hook. |
| `/calibrate cost` | Runs `calibrate-general/scripts/lint.sh` + the four-diagnostics ask. No run, no subagents, no edits. Single-number standing-context-cost snapshot. |

### Convenience flows (separate skills — multi-phase)

These spawn their own subagent chain and have their own preprocessing block, so they live as
standalone skills:

| Command | What it does |
|---|---|
| `/claude-calibration:calibration-audit` | Phase 1+2 only — baseline evaluation, no improvement plan, no edits. Periodic health check or CI gate. Enforced read-only by the audit-write-guard hook. |
| `/claude-calibration:calibration-diff` | Evaluator pass-2 against the previous run's baseline; no planner or calibrator. "What's changed since last calibration?" |

### Per-feature calibration (the bundles, on their own)

Skip the orchestration when you just want to clean up one feature:

| Command | What it does |
|---|---|
| `/claude-calibration:calibrate-skills` | Audit + tune every SKILL.md across user / project / plugins; promote heavy CLI-shellers to wrapper skills. |
| `/claude-calibration:calibrate-subagents` | Audit + tune every subagent — especially the "missing `tools:` → inherits everything" anti-pattern. |
| `/claude-calibration:calibrate-claude-md` | Trim oversized CLAUDE.md (move bulk into `.claude/rules/`); flag aspirational rules and committed secrets. |
| `/claude-calibration:calibrate-rules` | Add `paths:` scoping; split unconditional rules; flag overlap with CLAUDE.md. |
| `/claude-calibration:calibrate-settings` | Tighten permissions; move secrets to `.local`; flag `--dangerously-skip-permissions` and blanket-destructive allows. |
| `/claude-calibration:calibrate-hooks` | Narrow matchers; fix `exit 1` non-blocking; flag remote-fetch hook handlers. |
| `/claude-calibration:calibrate-mcp` | Move tokens to `${ENV_VAR}`; pair servers with wrapper skills (4-layer). |
| `/claude-calibration:calibrate-plugins` | Audit installed plugins; check your *own* plugin's structure (manifest, component placement, `version`). |
| `/claude-calibration:calibrate-general` | Cross-cutting: total context budget, layering hazards, "must-rule with no hook", the four diagnostics ask. |

Each bundle is `disable-model-invocation: true` — Claude can never auto-fire one, and the bundles
collectively add **zero** standing context cost when idle.

## The calibration loop

1. **Plan (init)** — planner creates `.claude/calibration/<timestamp>/plan.md` with the intent, the
   audit scope, and a phase checklist.
2. **Baseline evaluation** — evaluator dispatches per-feature work to the matching bundle (`reference.md`
   for the rubric; `scripts/lint.sh` for the actual numbers); writes per-feature, interactions, and
   intent-flow reports; emits **pattern signatures** with each finding.
3. **Plan (improve)** — planner reads the eval reports; **detects recurrence** (same signature ≥ 3×
   in this plan, or ≥ 2× across older runs); writes a prioritised improvement plan with two row
   kinds: **`edit`** (one-off fix) and **`create`** (a new feature artifact that enforces a standard
   so the problem stops recurring). Recurring patterns are auto-promoted to `create` when the intent
   matches `enforce | tighten | prevent recurrence | standardi[sz]e | harden`; otherwise they're
   listed under `### Enforcement opportunities` for the user to opt into.
4. **Approval gate** — orchestrator shows the plan; you reply `all` / `safe-only` / `project-only` /
   `<comma-separated ids>` / `skip` (or `/calibrate --yes` to skip the gate).
5. **Calibrate** — calibrator dispatches each approved row through its bundle: `templates/<x>.tmpl`
   for `create`, `examples/<case>/` for `edit`. After each change, re-runs `scripts/lint.sh` to verify.
   **Project-scope** changes are applied; **user-scope** (`~/.claude/...`) changes are written up as
   recommendations (writes outside the repo always prompt anyway).
6. **Delta evaluation** — evaluator re-audits; writes `eval-delta-*.md`; sets `last_evaluation` in
   `plan.md` (the durable record across `/clear`).
7. **Final report** — orchestrator composes the report from the run-folder files, prints it to stdout,
   and saves a copy at `.claude/calibration/<run>/final-report-*.md`.

Add `.claude/calibration/` to `.gitignore` unless you want runs committed (the calibrator offers to do
this).

## The recurrence → enforcement-creation insight

The optimization plan often has the same prompt repeating across rows — three subagents missing
`tools:`, four skills lacking `disable-model-invocation`, two skills both shelling out to `kubectl`.
That repetition is a strong signal: instead of repeatedly fixing the same thing by hand, **scaffold a
feature** (a hook, a path-scoped rule, a wrapper skill, a custom reviewer subagent) that *enforces*
the standard going forward. The planner detects recurrence; the calibrator dispatches the `create`
row through the matching `calibrate-<feature>` bundle (each bundle knows how to elevate an existing
instance *and* create one from a template).

The plugin doesn't only clean up a setup — it **hardens** it.

## Caveats — read these

- **Static audit, not a substitute for the built-in diagnostics.** `/doctor`, `/context all`,
  `/skills` (token sort), `/mcp` (per-server cost) are CLI-handled and **can't be invoked by an
  agent**. The evaluator works from your config files and *estimates* the context-cost numbers; its
  first report section asks you to paste those four outputs for the exact figures.
- **User-scope changes are recommended, not applied.** The calibrator auto-applies changes to
  *project* config (`CLAUDE.md`, `.claude/**`, `.mcp.json` in the repo). Changes to `~/.claude/**` are
  written up in the change report for you to apply by hand.
- **It edits your config.** Review the proposed plan before approving. `/calibrate` and every
  per-feature bundle are `disable-model-invocation: true` — Claude never triggers them on its own.
  Project changes are easy to `git revert`; `~/.claude/**` changes are yours to make.

## Developing the plugin

- After editing under `--plugin-dir`, run `/reload-plugins` to pick up skill/agent changes (a
  brand-new top-level `skills/` directory needs a full restart).
- **Audit the plugin against its own rubric.** `cd` into the plugin repo, run `claude --plugin-dir .`,
  then `/calibrate "audit this plugin's setup"` — three bundles auto-extend to find plugin-root
  files (`rules/`, `hooks/`, the manifest) and the calibrator's write-guard extends its allow-list
  to permit fixes. See [**`docs/usage.md` → Auditing this plugin itself**](docs/usage.md#auditing-this-plugin-itself).
- Keep `docs/` and the plugin's bundles in step with the official docs:
  - `/docs-status` — read-only: per-page Sources URLs, last-touched date, a staleness flag.
  - `/docs-update` — fetches the official pages (via the `docs-fetcher` subagent, one page at a time)
    and updates `docs/` in place, preserving the template structure and Sources sections.
  - `/plugin-update` — realigns the plugin's own components — including each
    `skills/calibrate-<feature>/reference.md`, `templates/`, and `scripts/lint.sh` — with the now-
    current `docs/`. Proposes a `version` bump and waits for approval.

## Why this plugin still costs ~zero standing context

Per the doc-set's own advice — the plugin is designed so that an idle session pays nothing:

- **All shipped skills are `disable-model-invocation: true`** — their descriptions are removed from
  context entirely (Claude can never auto-fire them); you fire them by name.
- **`rules/` is tightly path-scoped** — `signatures.md` and `dispatch.md` load only when files under
  `.claude/calibration/**` or `skills/calibrate-*/**` are open. Normal sessions pay nothing.
- **`hooks/` is zero-cost-unless-fires** — the two `PreToolUse` write-guards exit early and silently
  whenever the active subagent isn't `calibration-calibrator` (or the run isn't an audit-only run);
  they only return output (and therefore tax context) on a block.
- **No `.mcp.json`** — the plugin needs no external service.
- **No root `settings.json` `agent` key** — that would hijack the main thread in every enabled repo.
- **No `commands/`** — the legacy flat form; `skills/` is the current one.

## License

MIT.
