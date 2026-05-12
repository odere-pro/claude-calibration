[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Commands

The slash-command surface: **built-in commands** the CLI handles directly, **bundled skills** that
ship with Claude Code, and the note that **custom commands are skills** ([`skills.md`](skills.md)).

## Definition

A command is recognized only at the start of a message; text after the name is passed as arguments.
Three sources, with different [provenance](../glossary.md):
- **Built-in command** — handled by the CLI itself (`/doctor`, `/config`, `/memory`, …). Marked
  *Command* in the official reference. Most have **zero context cost**. A few (`/init`, `/review`,
  `/security-review`) are also reachable by Claude through the Skill tool.
- **Bundled skill** — a skill that ships with Claude Code (`/simplify`, `/debug`, `/batch`,
  `/loop`, `/fewer-permission-prompts`, `/claude-api`). Marked *Skill* in the reference; behaves
  like any skill (description in context, body on use).
- **Custom command** — your own `.claude/commands/foo.md` or `.claude/skills/foo/SKILL.md`. Custom
  commands have been **merged into skills** — both forms create `/foo` and work the same way; the
  skill form adds a directory for supporting files and more frontmatter. See [`skills.md`](skills.md).

## Scope

Built-in commands and bundled skills are **always available** — no scope. Custom commands follow
skill scoping (user / project / plugin; plugin entries namespaced `plugin:name`) — see
[`skills.md`](skills.md). Built-in commands and bundled skills can't be shadowed by a custom one of
the same name.

## Reference — built-in commands & bundled skills relevant to your setup

Type `/` to see everything; this is the config/diagnostic subset. **[B]** = bundled skill, rest =
built-in command.

### Set up

| Command | What it does |
|---------|--------------|
| `/init` | Generate a starter `CLAUDE.md` (`CLAUDE_CODE_NEW_INIT=1` → interactive multi-phase flow, also scaffolds skills/hooks; reads existing `AGENTS.md`/`.cursorrules`). |
| `/agents` | Create and edit subagent configurations (project / user / plugin). |
| `/mcp` | Add, remove, reconnect, and authenticate MCP servers. |
| `/plugin` | Browse marketplaces; install / enable / disable plugins. |
| `/permissions` | Add and edit allow / ask / deny rules. |

### Inspect / read

| Command | What it does |
|---------|--------------|
| `/memory` | List loaded `CLAUDE.md` / `CLAUDE.local.md` / rules files; open any for editing; toggle auto memory. |
| `/skills` | List skills; `t` sorts by token cost; `Space` toggles visibility (writes `skillOverrides` to `settings.local.json`). |
| `/hooks` | View hook configurations for tool events. |
| `/status` | Settings → Status tab: version, model, account, connectivity, loaded settings files. |
| `/context [all]` | Visualize context-window usage as a grid with optimization suggestions. |
| `/cost`, `/usage` (`/stats`) | Session cost, plan-usage limits, activity stats. |

### Edit / configure

| Command | What it does |
|---------|--------------|
| `/config` | Settings interface — theme, model, output style, and other keys. |
| `/model`, `/effort` | Select model / reasoning effort (persisted). |
| `/statusline` | Configure the status line. |
| `/terminal-setup` | Configure terminal key bindings (Shift+Enter, …). |
| `/keybindings` | Open or create `~/.claude/keybindings.json`. |
| `/fewer-permission-prompts` **[B]** | Scan transcripts for safe repeated calls → propose a tighter `permissions` allowlist. |
| `/reload-plugins` | Reload active plugins (skills, agents, hooks, MCP, LSP) without restarting. |
| editor mode | `editorMode: "vim"` in settings or via `/config` — `/vim` was removed in v2.1.92. |

### Diagnose / review

| Command | What it does |
|---------|--------------|
| `/doctor` | Diagnose & verify the install and settings; flags problems incl. an overflowing skill-listing budget. |
| `/debug [description]` **[B]** | Enable debug logging and walk through diagnosing a failure. |
| `/review [PR]` | Review a PR (or pending branch changes) locally. |
| `/security-review` | Analyze pending branch changes for security vulnerabilities. |
| `/simplify [focus]` **[B]** | Review recently changed files for reuse / quality / efficiency and apply fixes. |
| `/feedback` (`/bug`) | Submit feedback / a bug report with session context. |

### Custom commands → write a skill

`/deploy`, `/release`, `/fix-issue`, … — author these as skills (`.claude/skills/<name>/SKILL.md`,
or the legacy `.claude/commands/<name>.md`). Frontmatter, arguments (`$ARGUMENTS`, `$N`, `$name`),
dynamic context (`` !`cmd` ``), `disable-model-invocation`, scoping: all in [`skills.md`](skills.md).
The old slash-command CLI command `/migrate-installer` has been removed; `claude migrate-installer`
exists as a CLI subcommand in some versions.

## Validate

`/doctor` is the health check. `/skills` (token sort), `/context`, and `/mcp` show where commands
and skills are spending context. The plugin `harness-optimizer` agent reviews the overall command
set as part of a harness audit.

## Improve

**Should**
- Use `/doctor` first when anything's off; `/context` when the window feels tight.
- For custom commands: one job per command, keep the body lean, document arguments — see [`skills.md`](skills.md) **Improve**.
- Don't shadow built-in command names with a custom command.

| Limit | Value | Note |
|-------|-------|------|
| Built-in command context cost | ~0 | the CLI handles them; no description in context |
| Bundled skill context cost | low | description in context; body on use — same as any skill |

## Sources

- Commands reference (full built-in command + bundled skill list, marked Command/Skill) — <https://code.claude.com/docs/en/commands>
- Skills (custom commands are skills; frontmatter; bundled skills) — <https://code.claude.com/docs/en/skills>
- Extend Claude Code (context cost by feature) — <https://code.claude.com/docs/en/features-overview>
