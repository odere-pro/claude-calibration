[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Commands

The slash-command surface: **built-in commands** the CLI handles directly, **bundled skills** that
ship with Claude Code, and the fact that **custom commands are skills** ([`skills.md`](skills.md)).

## Definition

A command is recognized only at the _start_ of a message; text after the name is passed to it as
arguments. Three sources, with different origins:

- **Built-in command** — handled by the CLI itself (`/doctor`, `/config`, `/memory`, …). Marked
  _Command_ in the official reference. **Context cost: ~0** — these aren't injected into the model's
  context. A few (`/init`, `/review`, `/security-review`) are also reachable by Claude through the
  Skill tool; most (e.g. `/compact`) are not.
- **Bundled skill** — a skill that ships with Claude Code (`/simplify`, `/batch`, `/debug`,
  `/loop`, `/fewer-permission-prompts`, `/claude-api`). Marked _Skill_ in the reference; behaves
  exactly like any [skill](skills.md) — its description sits in context every request, its body loads
  when used. Prompt-based: it gives Claude detailed instructions and lets it orchestrate the work.
- **Custom command** — your own `.claude/commands/foo.md` _or_ `.claude/skills/foo/SKILL.md`. Custom
  commands have been **merged into skills** — both forms create `/foo` and behave the same way; the
  skill form adds a directory for supporting files, more frontmatter, and (optional) automatic
  model-invocation. See [`skills.md`](skills.md). If a skill and a command share a name, the skill wins.

## Scope

Built-in commands and bundled skills are **always available** — they have no scope, can't be
shadowed by a custom one of the same name, and can't be moved. Custom commands follow skill scoping
(user / project / plugin; plugin entries namespaced `plugin:name`) — see [`skills.md`](skills.md)
**Scope**.

## Reference — built-in commands & bundled skills relevant to your setup

Type `/` to see everything; this is the config/diagnostic subset. **[B]** = bundled skill, otherwise
a built-in command.

### Set up a project

| Command        | What it does                                                                                                                                                                                                                                                                                                                                                                                      |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/init`        | Scans the codebase with a subagent and generates a starter `CLAUDE.md` (build/test commands, conventions it discovers); suggests improvements if one exists rather than overwriting. `CLAUDE_CODE_NEW_INIT=1` → interactive multi-phase flow that also offers to scaffold skills and hooks and presents a reviewable proposal; reads an existing `AGENTS.md` / `.cursorrules` to seed the result. |
| `/agents`      | Opens the subagent manager — create, edit, and inspect subagent definitions across project / user / plugin scopes; for a new one it generates the identifier, description, and system prompt and lets you pick tools and model.                                                                                                                                                                   |
| `/mcp`         | Manages MCP server connections — add/remove servers, authenticate via OAuth, reconnect dropped ones, and view connection status and per-server token cost.                                                                                                                                                                                                                                        |
| `/plugin`      | Manages plugins — browse marketplaces, install / enable / disable plugins, and (with `--plugin-dir`/`--plugin-url` on the CLI) test local ones.                                                                                                                                                                                                                                                   |
| `/permissions` | Opens an interactive dialog to manage `permissions` allow / ask / deny rules — the approval rules that govern which tools and commands Claude can run without prompting.                                                                                                                                                                                                                          |

### Inspect / read state

| Command                      | What it does                                                                                                                                                                                                                              |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/memory`                    | Lists the `CLAUDE.md` / `CLAUDE.local.md` / `.claude/rules/*` files loaded this session and opens any for editing; toggles auto memory on/off; gives a link to the auto-memory folder. The "what instructions are actually loaded" check. |
| `/skills`                    | Lists available skills; press `t` to sort by token count, `Space` to cycle a skill's visibility (writes `skillOverrides` to `.claude/settings.local.json`), `Enter` to save. The "which skills are heavy / hidden" view.                  |
| `/hooks`                     | Opens a read-only browser of your configured hooks — which lifecycle events fire which handlers, across all settings layers and plugins.                                                                                                  |
| `/status`                    | Opens the Settings interface on the Status tab: version, account/org, active model, working directory, which `settings.json` files are loaded, and connectivity.                                                                          |
| `/context [all]`             | Visualizes current context-window usage as a colored grid and shows optimization suggestions — "where is the window going" (CLAUDE.md, skill descriptions, MCP tool names, conversation, …).                                              |
| `/cost`, `/usage` (`/stats`) | Show session cost, plan-usage limits, and activity stats (`/cost` is an alias for `/usage`; `/stats` opens it on the Stats tab).                                                                                                          |

### Edit / configure

| Command                             | What it does                                                                                                                                                                             |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/config`                           | Opens the Settings interface — change theme, model, output style, and other `settings.json` keys interactively; the change is written back to the right settings file.                   |
| `/model`, `/effort`                 | `/model` selects/changes the active model (and effort, where supported); `/effort` sets the reasoning-effort level. Both persist to settings.                                            |
| `/statusline`                       | Configures the status line — describe what you want and Claude writes the config, or run it to wire your own script.                                                                     |
| `/terminal-setup`                   | Configures terminal key bindings (Shift+Enter and other shortcuts); terminal-dependent, only shown when supported.                                                                       |
| `/keybindings`                      | Opens or creates `~/.claude/keybindings.json` for customizing in-app keyboard shortcuts.                                                                                                 |
| `/fewer-permission-prompts` **[B]** | Scans your transcripts for common read-only Bash/MCP calls and proposes a prioritized allowlist to add to `permissions` — cuts the routine approval prompts you keep approving anyway.   |
| `/reload-plugins`                   | Reloads all active plugins — skills, agents, hooks, plugin MCP servers, plugin LSP servers — so edits to a `--plugin-dir` plugin or a marketplace plugin take effect without restarting. |
| editor mode                         | Set `editorMode: "vim"` in `settings.json` or via `/config` — the standalone `/vim` command was removed in v2.1.92.                                                                      |

### Diagnose / review

| Command                        | What it does                                                                                                                                                                                                                                           |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/doctor`                      | Diagnoses and verifies the installation and settings — auto-updater, settings sanity, native-binary status, IDE/MCP connectivity, an overflowing skill-listing budget — and reports each with a status indicator. Run this first when something's off. |
| `/debug [description]` **[B]** | Enables debug logging for the current session and helps diagnose a failure you describe — collects the relevant logs and walks through what went wrong.                                                                                                |
| `/review [PR]`                 | Reviews a pull request (or, with no argument, the pending changes on the current branch) locally in your session — a read-only code review pass over the diff.                                                                                         |
| `/security-review`             | Analyzes the pending changes on the current branch specifically for security vulnerabilities — reviews the git diff and flags risky patterns and likely vulnerabilities.                                                                               |
| `/simplify [focus]` **[B]**    | Reviews your recently changed files for code reuse, quality, and efficiency and applies fixes; pass a focus area to narrow it.                                                                                                                         |
| `/feedback` (`/bug`)           | Submits feedback / a bug report about Claude Code with the current session context attached.                                                                                                                                                           |

### Custom commands → write a skill

`/deploy`, `/release`, `/fix-issue`, `/post-to-slack`, … — author these as skills
(`.claude/skills/<name>/SKILL.md`, or the legacy `.claude/commands/<name>.md`). Frontmatter,
arguments (`$ARGUMENTS`, `$N`, `$name`), dynamic context (`` !`cmd` `` runs a shell command and
inlines its output before Claude sees the skill), `disable-model-invocation` (only you can trigger
it), `context: fork` (run it in a subagent), scoping, and the size/structure recommendations are all
in [`skills.md`](skills.md). The old `/migrate-installer` slash command has been removed;
`claude migrate-installer` still exists as a CLI subcommand in some versions.

## Validate

| Invoke                                                          | What it does                                                                                                                                                                           |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/doctor` **[built-in]**                                        | The health check for the whole command/install surface — flags broken installs, invalid settings, and an overflowing skill-listing budget. Run it first whenever a command misbehaves. |
| `/skills` **[built-in]**                                        | Token-sorts your skills (bundled and custom) so you can see which ones are eating context.                                                                                             |
| `/context` **[built-in]**                                       | Shows the share of the context window going to skill descriptions and MCP tool names — the cost side of the command surface.                                                           |
| `harness-optimizer` agent **[plugin]**                          | Reviews the overall command/skill set as part of a harness audit — flags duplicates, overlap, and bloated custom-command bodies.                                                       |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Looks at the codebase and recommends custom commands/skills worth adding for the workflows it sees.                                                                                    |

## Improve

**Must**

- Don't shadow a built-in command name with a custom command — the built-in/bundled one always wins, so yours just won't run.

**Should**

- Use `/doctor` first when anything's off; `/context` (and `/skills` token-sort) when the window feels tight; `/mcp` to see per-server cost.
- For custom commands, follow the skill recommendations in [`skills.md`](skills.md): one job per command; keep the body lean (it's injected as a prompt on every invocation, and once loaded it stays for the session); a sharp, key-use-case-first `description` so it's found; document arguments with `argument-hint`; use `disable-model-invocation: true` for anything with side effects (`/deploy`) so Claude can't trigger it on its own; namespace it via a plugin (`plugin:name`) if many repos need it.
- Prefer skills (`SKILL.md`) over the legacy flat `commands/*.md` form for new custom commands — same behavior plus supporting files and richer frontmatter.

| Aspect                       | Recommendation                                                                     | Why                                                                                           |
| ---------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Built-in commands            | use them — `/doctor`, `/context`, `/skills`, `/mcp` are the first-line diagnostics | zero context cost; the CLI handles them                                                       |
| Bundled skills               | same context economics as any skill                                                | description in context; body on use                                                           |
| Custom command body          | keep lean; one job; document args                                                  | injected as a prompt on every invocation; stays in context for the session                    |
| Custom command `description` | key use case first; trigger keywords                                               | this is how Claude (and you) find it; truncated at 1,536 chars combined with `when_to_use`    |
| Side-effecting commands      | `disable-model-invocation: true`                                                   | stops Claude triggering `/deploy` etc. on its own; also drops the description to zero context |
| Sharing                      | package as a plugin (namespaced `plugin:name`)                                     | reuse across repos without name clashes                                                       |
| Form                         | prefer `skills/<name>/SKILL.md` over `commands/<name>.md`                          | richer features; commands form is legacy back-compat                                          |
| Naming                       | don't shadow built-ins                                                             | built-in wins; yours silently doesn't run                                                     |

## Sources

- Commands reference — the full built-in command + bundled skill list, marked Command/Skill — <https://code.claude.com/docs/en/commands>
- Skills — custom commands are skills; frontmatter; bundled skills — <https://code.claude.com/docs/en/skills>
- Extend Claude Code — context cost by feature — <https://code.claude.com/docs/en/features-overview>
