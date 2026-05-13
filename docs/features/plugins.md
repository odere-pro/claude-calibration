[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Plugins

The packaging layer: a plugin bundles skills, subagents, hooks, MCP/LSP servers, monitors, and
default settings into one installable, versioned unit — distributed via a **marketplace**.

## Definition

A plugin = a directory with a `.claude-plugin/plugin.json` manifest plus any of these at the *plugin
root* (NOT inside `.claude-plugin/` — only the manifest goes there): `skills/`, `commands/` (the
legacy flat skill form), `agents/`, `hooks/hooks.json`, `.mcp.json`, `.lsp.json` (language servers),
`monitors/monitors.json` (background monitors, auto-started when the plugin is active), `bin/`
(executables added to the Bash `PATH` while the plugin is enabled), and a root `settings.json` (only
`agent` and `subagentStatusLine` keys honored — `agent` lets a plugin activate one of its custom
agents as the main thread). Plugin **skills are namespaced** (`/plugin-name:skill-name`) so multiple
plugins coexist without clashes. A **marketplace** is a hosted collection of plugins you install
from (public, or a private repo for your team). Use plugins to reuse the same setup across
repositories or distribute to others; use standalone `.claude/` config for personal / single-project
work and quick experiments. **Context cost:** a plugin's cost is the *sum* of everything it ships —
its skills' descriptions (in context every request), its subagents' name+description (in the routing
context), its MCP servers' tool names (loaded at session start), plus its hooks/LSP/monitors — so
enabling one multiplies the per-feature costs at once. The smallest version unit: if the manifest
sets `version`, users only get updates when you bump it; if it's omitted and the plugin is
git-distributed, every commit counts as a new version.

## Scope

A plugin's contributed features take effect **wherever the plugin is enabled** (you can enable a
plugin user-wide or per-project; managed settings can force-enable one). In [layering](../glossary.md)
terms its features sit at the **plugin** scope — lowest priority for override-by-name features
(skills, subagents) — and plugin skills are namespaced so they can't clash with each other or with
your own. Plugin subagents **ignore** the `hooks`, `mcpServers`, and `permissionMode` frontmatter
fields.

On disk (this machine): `~/.claude/plugins/cache/<marketplace>/<plugin>/...` (installed payloads),
`~/.claude/plugins/marketplaces/<marketplace>/...` (cloned marketplace repos), enabled plugins
tracked in `~/.claude/plugins/installed_plugins.json`, registered marketplaces in
`known_marketplaces.json`.

## Configure

```text
my-plugin/
├── .claude-plugin/plugin.json     # manifest: name (= skill namespace) · description · version (optional) · author/homepage/repository/license (optional)
├── skills/<name>/SKILL.md          # skills — use this, not commands/, for new plugins
├── commands/*.md                   # legacy flat skill form
├── agents/*.md                     # subagents (plugin agents ignore hooks/mcpServers/permissionMode)
├── hooks/hooks.json                # hooks (same format as a settings.json `hooks` block)
├── .mcp.json                       # MCP servers
├── .lsp.json                       # LSP servers (code intelligence)
├── monitors/monitors.json          # background monitors — each stdout line is delivered to Claude as a notification
├── bin/                            # executables added to PATH while enabled
└── settings.json                   # default settings when enabled (only `agent`, `subagentStatusLine`; unknown keys ignored)
```

| Invoke | What it does |
|--------|--------------|
| `/plugin` **[built-in]** | The plugin manager — browse marketplaces, install / enable / disable plugins, register a marketplace (including a private repo). The single entry point for plugin lifecycle. |
| `claude --plugin-dir ./my-plugin` (CLI) | Loads a local plugin directory (or a `.zip`) for one session — for development; if it shares a name with an installed plugin, the local copy wins for that session. |
| `claude --plugin-url https://…/plugin.zip` (CLI) | Fetches a packaged plugin from a URL and loads it for one session (e.g. a CI build artifact); if the fetch fails, Claude reports a load error and starts without it. |
| `/reload-plugins` **[built-in]** | Reloads all active plugins — skills, agents, hooks, plugin MCP servers, plugin LSP servers — so edits take effect without restarting. |

## Validate

| Invoke | What it does |
|--------|--------------|
| `/plugin` **[built-in]** | Shows what's installed and enabled, and from which marketplace — your inventory check. |
| `/reload-plugins` **[built-in]** | Applies edits to a `--plugin-dir`/marketplace plugin so you can re-test its components (`/plugin-name:skill-name`, `/agents`, hooks) without restarting. |
| `/skills` **[built-in]** | The skills a plugin contributes show up here with token cost (`t` to sort) — so you can see what a plugin is costing you in context. |
| `/doctor` **[built-in]** | General health check; also flags the skill-listing budget that plugin skills feed (a heavy plugin can push it into overflow). |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Looks at the codebase and recommends plugins worth installing for the workflows it sees. |
| `harness-optimizer` agent **[plugin]** | Reviews the enabled-plugin set as part of a whole-harness audit — flags plugins whose cost outweighs their use. |

## Improve

**Must**
- Review what a plugin ships (and trust its marketplace) before enabling it — you're importing all of its skills, subagents, hooks, MCP servers, and LSP servers at once, each with its own context cost and potential side effects.

**Should**
- Install only what you actively use; disable rather than uninstall if you might want it back; prune the enabled set periodically.
- Keep plugins updated (`/reload-plugins` after local edits; bump the manifest `version` when distributing so users get the update).
- For a plugin you write: prefer `skills/` over the legacy `commands/`; keep `skills/`, `agents/`, `hooks/`, `.mcp.json`, etc. at the *plugin root* (a common mistake is putting them inside `.claude-plugin/`); ship a `README.md`; namespace is automatic from `name`.
- Use `/claude-code-setup:claude-automation-recommender` to decide what's actually worth having, and `/skills` / `harness-optimizer` to catch a plugin that's costing more context than it earns.

| Aspect | Recommendation | Why |
|--------|----------------|-----|
| Enabled plugins | only those in active use; disable (don't uninstall) for "maybe later" | a plugin = the sum of its skills + subagents + hooks + MCP + LSP + monitors, all loaded at once |
| Trust | review the contents and the marketplace before enabling | you're importing skills/hooks/MCP that can have side effects |
| Updates | keep current; bump `version` when distributing | users only get updates on a version bump (or per commit if `version` is omitted) |
| Authoring layout | `skills/` over `commands/`; directories at the plugin *root*, not in `.claude-plugin/`; ship a `README.md` | the #1 plugin bug is misplaced directories |
| Skill namespace | `plugin-name:skill-name` (automatic from `name`) | can't clash with other plugins or your own skills |
| Plugin subagents | they ignore `hooks`/`mcpServers`/`permissionMode` | copy into `.claude/agents/` if you need those |
| Root `settings.json` | only `agent`, `subagentStatusLine` honored | other keys silently ignored |
| Cost check | `/skills` (token sort), `/doctor` (budget), `harness-optimizer` | a heavy plugin can crowd out the skill-listing budget |

## Sources

- Plugins — structure, manifest, components, `--plugin-dir`/`--plugin-url`, `/reload-plugins`, converting standalone config — <https://code.claude.com/docs/en/plugins>
- Plugins reference — full manifest schema, version management, LSP servers, monitors, debugging tools — <https://code.claude.com/docs/en/plugins-reference>
- Discover and install plugins / Marketplaces — <https://code.claude.com/docs/en/discover-plugins> · <https://code.claude.com/docs/en/plugin-marketplaces>
- Extend Claude Code — plugins as the packaging layer; context cost — <https://code.claude.com/docs/en/features-overview>
