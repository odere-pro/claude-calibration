[← README](README.md) · [Install](install.md) · [Usage](usage.md) · [Setup structure](claude-structure.md)

# Glossary

The vocabulary used across this doc-set and the `claude-calibration` plugin, aligned with Claude
Code's own terms. A term lives in exactly one place; this page links to the page that owns each
fuller treatment rather than restating it.

## Claude Code configuration

- **Feature** — one configurable surface of a Claude Code setup. This doc-set has one page per
  feature: [CLAUDE.md](features/claude-md.md), [rules](features/rules.md),
  [settings](features/settings.md), [skills](features/skills.md), [subagents](features/subagents.md),
  [hooks](features/hooks.md), [MCP](features/mcp.md), [plugins](features/plugins.md), plus
  [commands](claude-config-commands.md).
- **Scope** — *where* a piece of config lives and therefore *who* it applies to: **user** (`~/.claude/`),
  **project** (`.claude/` in the repo), **local** (`*.local` / `.claude/settings.local.json`, not
  committed), **managed** (enterprise/admin), and **plugin-self** (files a plugin ships). See
  [claude-structure.md](claude-structure.md). This *config* scope is distinct from a plan row's
  **change scope** (`scope: project|user` — the target of a fix) and a run's **audit scope** (the
  breadth of what was evaluated).
- **Layering** — how two config files at different scopes combine: **additive** (both apply) or
  **override-by-name** (the higher-precedence one wins). See [claude-structure.md](claude-structure.md).
- **Precedence** — the order scopes win in a conflict (broadly: managed → local → project → user).
  Owned by [claude-structure.md](claude-structure.md).
- **CLAUDE.md** — the always-loaded project/user memory file. See [features/claude-md.md](features/claude-md.md).
- **Auto memory** — short facts Claude appends to a memory store during a session. See
  [features/claude-md.md](features/claude-md.md).
- **AGENTS.md import** — pulling the cross-tool `AGENTS.md` open standard into Claude Code via
  `@AGENTS.md` or a symlink. See [claude-agents-mapping.md](claude-agents-mapping.md).
- **Frontmatter** — the leading `--- … ---` YAML block in a `SKILL.md`, agent, or rule file that
  declares `name`, `description`, `paths`, `allowed-tools`, `model`, etc.
- **Built-in command** — a `/…` command handled by the CLI itself (e.g. `/doctor`, `/context`); it
  **cannot** be invoked by an agent.
- **Bundled skill** — a skill that ships with Claude Code out of the box.
- **Marketplace** — a git repo (or URL) whose `.claude-plugin/marketplace.json` lists installable
  plugins. Users `/plugin marketplace add <source>` then `/plugin install <plugin>@<marketplace>`.
  See [features/plugins.md](features/plugins.md) and [install.md](install.md).
- **Context cost** — the standing token weight a piece of config adds to every session. The whole
  point of calibration is keeping this near zero when idle. See [claude-structure.md](claude-structure.md).
- **`disable-model-invocation`** — frontmatter on a skill that removes its description from context
  and prevents Claude from auto-firing it; the user invokes it by name. Every skill this plugin
  ships sets it to `true`.

## Calibration plugin

- **Layer / 3-layer / 4-layer** — the plugin's architecture has three layers (per-feature skill
  bundles → worker subagents → the `/calibrate` entry point); a capability becomes **4-layer** when it
  also integrates an external system (CLI / MCP → skill → agent → entry point). The evaluator grades
  each capability against the rubric for the pattern it actually uses. See the [README](../README.md).
- **Bundle** — a `skills/calibrate-<feature>/` directory: one per feature, shipping `SKILL.md`,
  `reference.md` (the rubric), `scripts/enumerate.sh`, `scripts/lint.sh`, `templates/`, and `examples/`.
- **Orchestrator** — `/calibrate`: the opus entry point that chains planner → evaluator → calibrator
  → delta-eval → report and persists run state.
- **Dispatcher** — `/calibration`: the top-level menu/router above `/calibrate`.
- **Flow** — a standalone multi-phase skill that spawns its own subagent chain:
  `calibration-{audit,diff,doctor,onboarding}`.
- **Worker subagent** — one of `calibration-planner`, `calibration-evaluator`,
  `calibration-calibrator`, and the haiku-class `calibration-feature-evaluator` the evaluator fans
  out to. An agent the orchestrator/flows spawn **in its own context window** (so the parent stays
  lean); invoked only by them, never by the user directly. See **Subagent** under
  [Power words](#power-words).
- **Pattern signature** — a stable `<feature>:<short-name>` identifier attached to every finding
  (e.g. `subagent:missing-tools`). The canonical catalogue is [`rules/signatures.md`](../rules/signatures.md).
- **Recurrence** — the same signature firing ≥3× in one run or ≥2× across older runs; the planner
  treats it as a signal to enforce rather than re-fix.
- **Enforcement-creation** — promoting a recurrence into a `kind: create` row that scaffolds a new
  feature (a hook, path-scoped rule, or wrapper skill) so the issue stops recurring. This is the
  plugin's core move — see [SOFTWARE-3-0.md](../SOFTWARE-3-0.md).
- **Auto-promote** — the planner rule that, under enforcing intents (`enforce | tighten | prevent
  recurrence | standardize | harden`), elevates a recurrence straight to a `kind: create` row rather
  than leaving it as an opt-in. See [usage.md](usage.md).
- **Enforcement opportunity** — a `kind: create` row the planner surfaced but did **not**
  auto-promote; listed under `### Enforcement opportunities` in `plan.md` for you to opt into by id
  at the approval gate.
- **`kind: edit` vs `kind: create`** — an improvement-plan row that fixes one instance (`edit`) vs.
  one that scaffolds an enforcing artifact (`create`).
- **Dispatch map** — [`rules/dispatch.md`](../rules/dispatch.md): maps each signature (or family) to
  the bundle that owns its fix.
- **Run folder** — `.claude/calibration/<timestamp>/`: where a run's `plan.md`, eval reports, and
  final report live. Survives `/clear`. It's the audited project's data, not the plugin's.
- **`plan.md`** — the durable record of a run: intent, audit scope, phase checklist, and
  `last_evaluation`.
- **Approval gate** — the orchestrator pause where you choose which planned rows to apply
  (`all` / `safe-only` / `project-only` / `<ids>` / `skip`), unless `--yes` is set.
- **Intent** — the calibration goal driving a run (stated, or guessed if unset); shapes scope and
  whether recurrences auto-promote to enforcement.

## Power words

Power words are the precise terms whose deliberate, consistent use steers Claude accurately. Swap one
for a vaguer synonym and the skill or agent loses the intent it carried — so skills and agents use
these **verbatim**. (The terms above are power words too; the entries here are the ones whose meaning
is easiest to lose.)

- **Agent** — a unit defined by a system prompt + `tools` + `model` that performs a task. The
  user-facing entry points (`/calibrate`, `/calibration`) are *skills*, not agents; the actual
  agents ship under `agents/`. See [Subagent](#power-words) for the narrower term.
- **Subagent** — an **agent the parent runs in its own context window**, invoked via the `Agent`
  tool, never by the user. The "sub" is the power word: it encodes the parent→child relationship
  **and** the reason you reach for one — isolate work in a fresh window so the parent's context stays
  lean (the evaluator fans nine feature audits out to haiku subagents). Claude Code's own term; see
  [features/subagents.md](features/subagents.md). Distinct from **Agent** — the two coexist.
- **Fan out** — a parent spawning several subagents in parallel, each in its own context window, to
  cover breadth cheaply (evaluator → `calibration-feature-evaluator` ×9).
- **Baseline** — Pass 1 of an evaluation: the full audit that later passes compare against.
- **Delta** — Pass 2: a re-audit of the same scope, scored against the baseline
  (`resolved | partial | open | new`).
- **Scaffold** — generate a new artifact (a hook, path-scoped rule, or wrapper skill) from a
  template — the `kind: create` action, as opposed to editing an existing one.
- **Verify** — re-run the relevant `scripts/lint.sh` after a change and confirm the signature no
  longer fires.
- **Rubric** — a bundle's `reference.md`: the Must/Should/Limit standard a feature is graded against.

### Don't confuse

| Use this | …not this | Because |
| --- | --- | --- |
| **subagent** | agent | a subagent runs in its **own context window**; "agent" drops that intent |
| **orchestrator** (`/calibrate`) | dispatcher / flow | the orchestrator chains the whole loop; the **dispatcher** (`/calibration`) only routes; a **flow** is one standalone multi-phase skill |
| **`kind: create`** | edit | `create` **scaffolds enforcement**; `edit` fixes one instance |
| **delta** | baseline | the delta is the re-eval; the baseline is the first pass it compares against |
| **evaluate** | audit | the evaluator runs both passes; `audit` is the read-only pass-1-only flow |
| **change scope** / **audit scope** | scope | reserve bare **scope** for *where config lives* |

## Sources

- Claude Code configuration vocabulary — grounded in <https://code.claude.com/docs/en/overview> and
  the per-feature pages linked above.
- Plugin / marketplace terms — <https://code.claude.com/docs/en/plugins>.
