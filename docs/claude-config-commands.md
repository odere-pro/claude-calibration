# Config commands — native ways to update / improve each entity

Every built-in command (and the skills that go with it) that **creates, edits, updates, or
improves** a configuration entity — grouped by entity. Tables: column 1 is how you invoke it,
column 2 is what it does in one sentence.

> **Provenance — read this first.** Claude Code itself ships: built-in slash commands
> (`/init`, `/memory`, `/config`, `/permissions`, `/hooks`, `/mcp`, `/agents`, `/skills`,
> `/plugin`, `/model`, `/effort`, `/statusline`, `/terminal-setup`, `/doctor`, …) and a small
> set of **bundled skills** (`/simplify`, `/debug`, `/batch`, `/loop`, `/fewer-permission-prompts`,
> `/claude-api`). A few built-ins are also reachable via the Skill tool: `/init`, `/review`,
> `/security-review`. **Everything else** referenced below (`/skill-create`, `/learn`, `/evolve`,
> `/promote`, `/prune`, `/claude-md-management:*`, `/claude-code-setup:*`, `/update-config`, …)
> comes from **plugins** (e.g. the official `claude-md-management`, `claude-code-setup` plugins)
> or this user's setup — check / install with `/plugin`. Plugin commands are namespaced
> `plugin:name`. Items below are tagged **[built-in]**, **[bundled skill]**, or **[plugin]**.

This is the *write* side; for the *evaluate / audit / recommend* side see
[`claude-evaluators.md`](claude-evaluators.md). For what each entity is,
[`claude-project-configuration.md`](claude-project-configuration.md); for where files live,
[`claude-structure.md`](claude-structure.md).

**Invocation legend**

| Form | How to invoke | Example |
|------|---------------|---------|
| `/command` (built-in) | typed at the prompt; the CLI handles it | `/init` |
| `/name` (bundled skill) | typed at the prompt, or the Skill tool | `/simplify` |
| `/name` (skill) | a skill from a plugin or your setup | `/skill-create` |
| `/plugin:name` | a skill from a named plugin | `/claude-md-management:revise-claude-md` |
| `name` agent | a subagent — Agent tool with that `subagent_type` | `statusline-setup` agent |
| `#…` | prompt prefix — type `#` then text at the start of a message | `# always use pnpm` |
| `claude …` | run in a terminal, not inside a session | `claude mcp add …` |

---

## `CLAUDE.md` (the instruction file) — and `AGENTS.md` via the bridge

Claude Code reads `CLAUDE.md`. To use the open-standard `AGENTS.md`, point `CLAUDE.md` at it with
`@AGENTS.md` or symlink (`ln -s AGENTS.md CLAUDE.md`).

| Invoke | What it does |
|--------|--------------|
| `/init` **[built-in]** | Generates a starter `CLAUDE.md` (set `CLAUDE_CODE_NEW_INIT=1` for the interactive multi-phase flow; reads an existing `AGENTS.md` / `.cursorrules` etc. to seed it). |
| `/memory` **[built-in]** | Edits `CLAUDE.md` / `CLAUDE.local.md` / `.claude/rules/*` files, toggles auto-memory, opens the auto-memory folder. |
| `#<text>` **[built-in]** | Asks Claude to remember something — saved to *auto-memory* (`~/.claude/projects/<project>/memory/`), not `CLAUDE.md`. |
| `/claude-md-management:revise-claude-md` **[plugin]** | Updates `CLAUDE.md` with learnings from the current session. |
| `/claude-md-management:claude-md-improver` **[plugin]** | Audits `CLAUDE.md`/`AGENTS.md` against quality templates and applies targeted fixes. |

## `.claude/settings.json` (+ `settings.local.json`)

| Invoke | What it does |
|--------|--------------|
| `/config` **[built-in]** | Opens the Settings interface to change theme, model, output style, and other keys. |
| `/permissions` **[built-in]** | Opens an interactive dialog to add/edit allow / ask / deny rules. |
| `/model` **[built-in]** | Selects the model (and effort, for models that support it); persisted to settings. |
| `/effort` **[built-in]** | Sets the reasoning effort level; persisted via `effortLevel`. |
| `/statusline` **[built-in]** | Configures the status line — describe what you want, or wire a script. |
| `/terminal-setup` **[built-in]** | Configures terminal key bindings (Shift+Enter, etc.) — terminal-dependent. |
| `/keybindings` **[built-in]** | Opens or creates `~/.claude/keybindings.json`. |
| `/fewer-permission-prompts` **[bundled skill]** | Scans your transcripts for safe repeated calls and proposes a tighter `permissions` allowlist. |
| `/update-config` **[plugin]** | Programmatically edits `settings.json` — permissions, env vars, hooks. |
| editor mode | `/vim` was **removed in v2.1.92** — set `editorMode: "vim"` in settings or change it in `/config`. |

## `.claude/agents/*.md` — subagents

| Invoke | What it does |
|--------|--------------|
| `/agents` **[built-in]** | Creates and edits subagent definitions interactively (project, user, or plugin scope). |

## `.claude/commands/*.md` and `.claude/skills/<name>/SKILL.md` — slash commands / skills

Custom commands have been merged into skills; both `.claude/commands/foo.md` and
`.claude/skills/foo/SKILL.md` create `/foo`.

| Invoke | What it does |
|--------|--------------|
| *(add a file)* | Drop a `.md` in `.claude/commands/`, or a `<name>/SKILL.md` in `.claude/skills/` — there is no built-in generator for hand-written ones. |
| `/skill-create` **[plugin]** | Generates a `SKILL.md` from coding patterns in your git history. |
| `/plugin` **[built-in]** | Installs commands/skills packaged in a plugin (and `/reload-plugins` picks up edits). |

## `.claude/skills/<skill>/SKILL.md` — skills (manage / improve)

| Invoke | What it does |
|--------|--------------|
| `/skills` **[built-in]** | Lists skills; `Space` toggles visibility (writes `skillOverrides` to `settings.local.json`), `t` sorts by token count. |
| `/skill-create` **[plugin]** | Generates a `SKILL.md` from git-history patterns. |
| `/learn` · `/learn-eval` **[plugin]** | Extracts a reusable pattern from the session into a skill/instinct (`-eval` self-grades first). |
| `/evolve` **[plugin]** | Restructures or merges existing skills/instincts. |
| `/promote` · `/prune` · `/instinct-import` · `/instinct-export` **[plugin]** | Move instincts between scopes / files; delete stale ones. |
| `/plugin` **[built-in]** | Installs skills packaged in a plugin marketplace. |

## `.claude/hooks/` + `settings.json` → `hooks`

| Invoke | What it does |
|--------|--------------|
| `/hooks` **[built-in]** | Views hook configurations for tool events. (Hook *entries* are edited directly in a `settings.json` `hooks` block or a plugin's `hooks/hooks.json`.) |
| `/update-config` **[plugin]** | Writes hook definitions into `settings.json`. |
| `/init` **[built-in]** | With `CLAUDE_CODE_NEW_INIT=1`, the interactive flow can scaffold hooks alongside `CLAUDE.md`. |

## `.mcp.json` — MCP servers

| Invoke | What it does |
|--------|--------------|
| `/mcp` **[built-in]** | Adds, removes, reconnects, and authenticates MCP servers. |
| `claude mcp add <name> …` **[built-in CLI]** | Adds an MCP server from the terminal. |
| `/plugin` **[built-in]** | Installs MCP servers bundled with a plugin. |

## Plugins (user-level, layered onto the project)

| Invoke | What it does |
|--------|--------------|
| `/plugin` **[built-in]** | Browses marketplaces and installs / enables / disables plugins. |
| `/reload-plugins` **[built-in]** | Reloads active plugins (skills, agents, hooks, MCP, LSP) to apply changes without restarting. |

## Whole install / config (cross-cutting)

| Invoke | What it does |
|--------|--------------|
| `/doctor` **[built-in]** | Diagnoses and verifies the install and settings, offering fixes. |
| `/upgrade` **[built-in]** | Opens the upgrade page to switch to a higher plan tier. (The old `/migrate-installer` slash command has been removed; `claude migrate-installer` still exists as a CLI command in some versions.) |
| `/config` **[built-in]** | The general interactive settings editor. |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Audits the codebase and recommends hooks / subagents / skills / plugins / MCP servers to add. |

---

## Sources

- Commands reference (built-in commands, bundled skills) — <https://code.claude.com/docs/en/commands>
- Settings — <https://code.claude.com/docs/en/settings> · Memory — <https://code.claude.com/docs/en/memory>
- Subagents — <https://code.claude.com/docs/en/sub-agents> · Skills — <https://code.claude.com/docs/en/skills>
- Hooks — <https://code.claude.com/docs/en/hooks> · MCP — <https://code.claude.com/docs/en/mcp>
- Plugins — <https://code.claude.com/docs/en/plugins> · CLI reference — <https://code.claude.com/docs/en/cli-reference>
- (Plugin-provided items: install via `/plugin`; the official marketplace is browsable from `/plugin`.)
