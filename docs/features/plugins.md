[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Plugins

The packaging layer: a plugin bundles skills, subagents, hooks, MCP/LSP servers, monitors, and
default settings into one installable, versioned unit — distributed via a **marketplace**.

## Definition

A plugin = a directory with a `.claude-plugin/plugin.json` manifest plus any of these at the
plugin root (NOT inside `.claude-plugin/`): `skills/`, `commands/` (legacy skill form), `agents/`,
`hooks/hooks.json`, `.mcp.json`, `.lsp.json`, `monitors/monitors.json`, `bin/` (added to the Bash
`PATH` while enabled), and a root `settings.json` (only `agent` and `subagentStatusLine` honored).
Plugin **skills are namespaced** (`/plugin-name:skill-name`) so multiple plugins can coexist. A
**marketplace** is a hosted collection of plugins you install from. Use plugins to reuse the same
setup across repositories or distribute to others; use standalone `.claude/` config for personal /
single-project work. **Context cost:** a plugin's cost is the *sum* of everything it ships — its
skills' descriptions, its subagents' names+descriptions, its hooks, its MCP servers' tool names —
so enabling one multiplies the per-feature costs at once.

## Scope

A plugin's contributed features take effect **wherever the plugin is enabled** (you can enable a
plugin user-wide or per-project). In [layering](../glossary.md) terms its features sit at the
**plugin** scope — lowest priority for override-by-name features (skills, subagents), and namespaced
skills can't clash. Plugin subagents ignore the `hooks`, `mcpServers`, and `permissionMode`
frontmatter fields.

On disk (this machine): `~/.claude/plugins/cache/<marketplace>/<plugin>/...` (installed payloads),
`~/.claude/plugins/marketplaces/<marketplace>/...` (cloned marketplace repos), and enabled plugins
tracked in `~/.claude/plugins/installed_plugins.json` (and `known_marketplaces.json`).

## Configure

```text
my-plugin/
├── .claude-plugin/plugin.json     # manifest: name (= skill namespace), description, version, author, …
├── skills/<name>/SKILL.md          # skills (use this, not commands/, for new plugins)
├── commands/*.md                   # legacy flat skill form
├── agents/*.md                     # subagents
├── hooks/hooks.json                # hooks (same format as a settings.json `hooks` block)
├── .mcp.json                       # MCP servers
├── .lsp.json                       # LSP servers (code intelligence)
├── monitors/monitors.json          # background monitors (auto-started when enabled)
├── bin/                            # executables added to PATH while enabled
└── settings.json                   # default settings when enabled (only `agent`, `subagentStatusLine`)
```

Manifest: `name` (unique id + skill namespace), `description`, optional `version` (if set, users
only get updates when you bump it; if omitted with a git-distributed plugin, every commit counts as
a new version), optional `author`, `homepage`, `repository`, `license`.

| Invoke | What it does |
|--------|--------------|
| `/plugin` **[built-in]** | Browse marketplaces; install / enable / disable plugins. |
| `claude --plugin-dir ./my-plugin` (CLI) | Load a local plugin (or a `.zip`) for one session — for development. |
| `claude --plugin-url https://…/plugin.zip` (CLI) | Fetch and load a packaged plugin from a URL for one session. |
| `/reload-plugins` **[built-in]** | Reload active plugins (skills, agents, hooks, MCP, LSP) to apply changes without restarting. |
| `claude marketplace add …` / `/plugin` | Register a marketplace (incl. a private repo). |

## Validate

| Invoke | What it does |
|--------|--------------|
| `/plugin` **[built-in]** | See what's installed / enabled. |
| `/reload-plugins` **[built-in]** | Apply edits, then check skills (`/plugin-name:skill-name`), agents (`/agents`), hooks. |
| `/skills` **[built-in]** | The skills a plugin contributes show up here, with token cost (`t` to sort). |
| `/doctor` **[built-in]** | General health check (also the skill-listing budget that plugin skills feed). |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Recommends plugins worth installing for the codebase. |
| `harness-optimizer` agent **[plugin]** | Reviews the enabled-plugin set as part of a harness audit. |

## Improve

**Must**
- Review what a plugin ships (and trust its marketplace) before enabling it — you're importing all of its skills, subagents, hooks, and MCP servers at once.

**Should**
- Install only what you use; disable rather than uninstall if you might want it back; prune periodically.
- Keep plugins updated (`/reload-plugins` after edits; bump `version` when distributing).
- For your own plugins, prefer `skills/` over `commands/`, keep directories at the plugin root (not inside `.claude-plugin/`), and ship a `README.md`.
- Use `/claude-code-setup:claude-automation-recommender` to decide what's actually worth having.

| Limit / fact | Value | Note |
|--------------|-------|------|
| Context cost | sum of contributed features | a plugin = its skills + subagents + hooks + MCP + LSP + monitors |
| Skill namespace | `plugin-name:skill-name` | can't clash with other plugins or your own skills |
| Plugin subagents | ignore `hooks`/`mcpServers`/`permissionMode` | copy into `.claude/agents/` if you need those |
| Root `settings.json` | only `agent`, `subagentStatusLine` honored | other keys silently ignored |

## Sources

- Plugins (structure, manifest, components, `--plugin-dir`/`--plugin-url`, migration) — <https://code.claude.com/docs/en/plugins>
- Plugins reference (full manifest schema, version management, debugging) — <https://code.claude.com/docs/en/plugins-reference>
- Discover and install plugins / Marketplaces — <https://code.claude.com/docs/en/discover-plugins> · <https://code.claude.com/docs/en/plugin-marketplaces>
- Extend Claude Code (plugins as the packaging layer) — <https://code.claude.com/docs/en/features-overview>
