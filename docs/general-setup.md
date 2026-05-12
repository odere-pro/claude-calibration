[← README](README.md) · [Glossary](glossary.md)

# General setup

The Claude Code setup as a whole: the extension layer, where it lives on disk, how scopes layer,
and how to check and tune the lot. Per-feature detail is in [`features/`](README.md#features).

## Definition

Claude Code = a model + [built-in tools](https://code.claude.com/docs/en/how-claude-code-works) for
files, search, execution, and web. On top of those you add an **extension layer** — the
[features](glossary.md): **CLAUDE.md**, **`.claude/rules/`**, **Skills**, **Subagents**, **MCP**,
**Hooks**, **Plugins** (plus **Settings**, the config substrate, and the experimental **Agent
teams** — see the [official docs](https://code.claude.com/docs/en/agent-teams)). Each plugs into a
different part of the agentic loop and has its own [context cost](glossary.md) and load timing
(see [Improve](#improve)).

Everything lives in one of three places: `~/.claude/` (and `~/.claude.json`) for user-wide config,
`.claude/` (and `CLAUDE.md`, `.mcp.json`) in the repo for project config, and the managed-policy
directory for admin-enforced config. Most of `~/.claude/` is **runtime state** Claude writes
itself (transcripts, auto memory, caches) — not config you hand-edit.

```text
~/
├── .claude.json                # user + per-project MCP servers, project list, history, oauth, trust
└── .claude/
    ├── settings.json           # user settings (permissions, env, model, hooks, statusLine, …)  → features/settings.md
    ├── settings.local.json     # user-local overrides (git-ignored)
    ├── CLAUDE.md               # user instructions, all projects                                  → features/claude-md.md
    ├── rules/*.md              # user rules (auto-loaded, optional `paths:` scoping)              → features/rules.md
    ├── agents/*.md             # user subagents                                                   → features/subagents.md
    ├── skills/<name>/SKILL.md  # user skills                                                       → features/skills.md
    ├── commands/*.md           # user custom commands (legacy skill form)                          → features/commands.md
    ├── hooks/                  # user hook scripts (entries go in settings.json `hooks`)          → features/hooks.md
    ├── plugins/                # installed plugins + marketplaces (installed_plugins.json, …)     → features/plugins.md
    ├── statusline-command.sh   # status-line script (wired via settings.statusLine)
    ├── keybindings.json        # custom key bindings (via /keybindings)
    └── projects/<project>/     # RUNTIME: transcripts (*.jsonl) + memory/ (auto memory)  · sessions/ session-env/
                                #   shell-snapshots/ file-history/ tasks/ telemetry/ cache/ …  — Claude writes these

<repo>/
├── CLAUDE.md                   # project instructions (or ./.claude/CLAUDE.md); CLAUDE.local.md for personal, git-ignored
├── .mcp.json                   # project MCP servers
└── .claude/
    ├── settings.json           # project settings (committed) · settings.local.json (personal, git-ignored)
    ├── rules/*.md  agents/*.md  skills/<name>/SKILL.md  commands/*.md  hooks/   # project-scoped features

managed policy (admin-deployed, highest precedence — not present unless your org deploys it):
  macOS    /Library/Application Support/ClaudeCode/{managed-settings.json, managed-settings.d/, CLAUDE.md, managed-mcp.json, agents/, skills/}
  Linux/WSL /etc/claude-code/{…same…}
  Windows  C:\Program Files\ClaudeCode\{…same…}   (also Registry HKLM\SOFTWARE\Policies\ClaudeCode; macOS prefs domain com.anthropic.claudecode)
```

## Scope

Features can be defined at several [scopes](glossary.md) — **managed**, **user**, **project**,
**local**, **plugin** — and Claude Code combines them in one of two ways ([layering](glossary.md)):

| Layering mode        | Features                                   | What happens with multiple definitions                                             |
| -------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------- |
| **Additive**         | `CLAUDE.md` / `.claude/rules/`, **hooks**  | every scope contributes; nothing is suppressed                                     |
| **Override-by-name** | **skills**, **subagents**, **MCP servers** | one definition wins by priority; plugin entries are namespaced so they can't clash |

### `settings.json` precedence (highest → lowest)

1. **Managed** (`managed-settings.json`) — cannot be overridden
2. **Command-line arguments**
3. **Local** (`.claude/settings.local.json`)
4. **Project** (`.claude/settings.json`)
5. **User** (`~/.claude/settings.json`)

### Override-by-name priority

- **Skills**: managed > user > project. Plugin skills are namespaced (`plugin:name`), so no clash.
- **Subagents**: managed > `--agents` CLI flag > project (`.claude/agents/`) > user (`~/.claude/agents/`) > plugin.
- **MCP servers**: local > project > user (plugin and managed servers also merge in).

### CLAUDE.md load order (additive — files are concatenated, not overridden)

Managed-policy `CLAUDE.md` → user `~/.claude/CLAUDE.md` (+ `~/.claude/rules/*`) → project
`CLAUDE.md` / `CLAUDE.local.md` discovered by walking **up** the directory tree from cwd
(ordered filesystem-root → cwd, so the closest file is read **last**; `CLAUDE.local.md` after
`CLAUDE.md` at each level; `.claude/rules/*` at the priority of `.claude/CLAUDE.md`). Subdirectory
`CLAUDE.md` files _below_ cwd load on demand. Use `claudeMdExcludes` in `.claude/settings.local.json`
to skip other teams' ancestor files in a monorepo. Details in [`features/claude-md.md`](features/claude-md.md).

### `AGENTS.md`

Claude Code reads **`CLAUDE.md`, not `AGENTS.md`**. To use the open standard, [import it](glossary.md):
put `@AGENTS.md` inside `CLAUDE.md`, or `ln -s AGENTS.md CLAUDE.md`. See
[`reference/agents-md.md`](reference/agents-md.md).

### Not loaded from `--add-dir`

`--add-dir` grants file access, not config discovery — with two exceptions: `.claude/skills/` and
`CLAUDE.md` files (the latter only with `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`). Subagents,
custom commands, hooks, and `.mcp.json` are _not_ read from added directories.

## Configure

You don't edit "the setup" as one thing — you configure each feature via its files plus the
built-in commands. The first-session workflow: `/init` (generate `CLAUDE.md`) → `/memory` (refine
it) → `/mcp` and `/agents` (servers / subagents the project needs) → `/permissions` (approval
rules). The complete catalogue of built-in commands and bundled skills — and which one touches
which feature — is in [`features/commands.md`](features/commands.md); each feature doc's
**Configure** section lists the commands specific to it.

## Validate

| Invoke                                                          | What it does                                                                                                                                         |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/doctor` **[built-in]**                                        | Diagnoses and verifies the install and settings; flags problems, including an overflowing skill-listing budget. Run this first when something's off. |
| `/status` **[built-in]**                                        | Opens Settings on the Status tab — version, model, account, connectivity, which `settings.json` files are loaded.                                    |
| `/context` **[built-in]**                                       | Visualizes context usage as a grid and shows optimization suggestions — "where is my context window going".                                          |
| `/mcp` **[built-in]**                                           | Shows per-server connection/OAuth status and token cost.                                                                                             |
| `/skills` **[built-in]**                                        | Lists skills; press `t` to sort by token cost.                                                                                                       |
| `harness-optimizer` agent **[plugin]**                          | Reviews settings, hooks, model routing, and subagents for reliability, cost, and throughput; proposes concrete changes.                              |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Audits the codebase and recommends features (hooks / subagents / skills / plugins / MCP) worth adding.                                               |
| `claude-code-guide` agent **[plugin]**                          | Answers "is this config valid / how should X be set".                                                                                                |

Quick start: `/doctor` for the built-in health check → `/context` and `/skills` to see where the
window goes → (if installed) `harness-optimizer` to tune what exists and `claude-automation-recommender`
for what's missing. Per-feature audit tools are in each feature doc's **Validate** section.

## Improve

### Context cost — what each feature loads, and when

| Feature               | When it loads          | What loads                                                                                                 | Cost                                                                           |
| --------------------- | ---------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| **CLAUDE.md** / rules | session start          | full content of all in-scope files                                                                         | **every request**                                                              |
| **Skills**            | session start + on use | descriptions every request; full body when invoked                                                         | low (description); `disable-model-invocation: true` → zero until you invoke it |
| **MCP servers**       | session start          | tool names at start; full JSON schemas on demand (tool search keeps idle tools cheap)                      | low until a tool is used                                                       |
| **Subagents**         | when spawned           | fresh isolated window: system prompt + preloaded `skills:` + inherited `CLAUDE.md`/git status + the prompt | isolated from the main session                                                 |
| **Hooks**             | on trigger             | nothing (runs externally)                                                                                  | zero unless the hook returns output                                            |

Rule of thumb: **if it's loaded but unused, delete it.** Unused skills, dead MCP servers, stale
`CLAUDE.md` lines, and near-duplicate subagents are pure context tax. (`/doctor` reports an
overflowing skill-listing budget; `/mcp` shows per-server token cost; `/context` shows the whole
picture.)

### Always-on checklist

- [ ] `CLAUDE.md` is < ~200 lines, concrete, secret-free; bulk content lives in `.claude/rules/`
- [ ] `AGENTS.md` (if present) is imported from `CLAUDE.md` (`@AGENTS.md` or a symlink)
- [ ] Permissions allowlist covers the safe-and-frequent; nothing destructive is blanket-allowed; never `--dangerously-skip-permissions`
- [ ] No secrets in any committed file (`settings.json`, `.mcp.json`, `commands/`, `agents/`, `CLAUDE.md`)
- [ ] Subagents have explicit/minimal `tools` (not the inherit-all default), sharp descriptions, cheapest capable model
- [ ] Active skills are non-overlapping with key-use-case-first descriptions; unused ones are `skillOverrides`-off or deleted
- [ ] Hooks are sub-second, narrowly matched, locally sourced, ordered cheap→expensive (heavy work on `Stop`), and use `exit 2` to block
- [ ] `.mcp.json` lists only servers in active use; tokens are OAuth/env-referenced; dead servers cleaned up
- [ ] Only plugins in active use are enabled
- [ ] Anything the team needs is committed; nothing critical lives only in someone's `~/.claude/`
- [ ] Periodic audit: `/doctor` → `/context` → `/skills` (token sort) → (plugin) `harness-optimizer` → `claude-automation-recommender` → `claude-md-improver`
- [ ] Large tasks: don't work in the last ~20% of the context window — `/compact` or start fresh; route model to task complexity

Per-feature **Must / Should** rules and concrete numeric limits are in each feature doc's **Improve** section.

## Sources

- Extend Claude Code (the feature set, layering, context costs) — <https://code.claude.com/docs/en/features-overview>
- Settings (scopes, precedence, managed paths) — <https://code.claude.com/docs/en/settings>
- Memory (CLAUDE.md, rules, load order, `AGENTS.md`) — <https://code.claude.com/docs/en/memory>
- Commands — <https://code.claude.com/docs/en/commands> · Subagents — <https://code.claude.com/docs/en/sub-agents>
- Skills — <https://code.claude.com/docs/en/skills> · Hooks — <https://code.claude.com/docs/en/hooks> · MCP — <https://code.claude.com/docs/en/mcp> · Plugins — <https://code.claude.com/docs/en/plugins>
- How Claude Code works — <https://code.claude.com/docs/en/how-claude-code-works> · Overview — <https://code.claude.com/docs/en/overview>
