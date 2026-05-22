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
  [claude-structure.md](claude-structure.md).
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
  bundles → worker agents → the `/calibrate` entry point); a capability becomes **4-layer** when it
  also integrates an external system (CLI / MCP → skill → agent → entry point). The evaluator grades
  each capability against the rubric for the pattern it actually uses. See the [README](../README.md).
- **Bundle** — a `skills/calibrate-<feature>/` directory: one per feature, shipping `SKILL.md`,
  `reference.md` (the rubric), `scripts/enumerate.sh`, `scripts/lint.sh`, `templates/`, and `examples/`.
- **Orchestrator** — `/calibrate`: the opus entry point that chains planner → evaluator → calibrator
  → delta-eval → report and persists run state.
- **Dispatcher** — `/calibration`: the top-level menu/router above `/calibrate`.
- **Flow** — a standalone multi-phase skill that spawns its own subagent chain:
  `calibration-{audit,diff,doctor,onboarding}`.
- **Worker agent** — one of `calibration-planner`, `calibration-evaluator`, `calibration-calibrator`,
  and the haiku-class `calibration-feature-evaluator` the evaluator fans out to. Invoked only by the
  orchestrator/flows, never by the user directly.
- **Pattern signature** — a stable `<feature>:<short-name>` identifier attached to every finding
  (e.g. `subagent:missing-tools`). The canonical catalogue is [`rules/signatures.md`](../rules/signatures.md).
- **Recurrence** — the same signature firing ≥3× in one run or ≥2× across older runs; the planner
  treats it as a signal to enforce rather than re-fix.
- **Enforcement-creation** — promoting a recurrence into a `kind: create` row that scaffolds a new
  feature (a hook, path-scoped rule, or wrapper skill) so the issue stops recurring. This is the
  plugin's core move — see [SOFTWARE-3-0.md](../SOFTWARE-3-0.md).
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

## Sources

- Claude Code configuration vocabulary — grounded in <https://code.claude.com/docs/en/overview> and
  the per-feature pages linked above.
- Plugin / marketplace terms — <https://code.claude.com/docs/en/plugins>.
