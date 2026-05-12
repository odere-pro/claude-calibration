[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# MCP

Model Context Protocol — the open standard for connecting Claude Code to external services and
tools (databases, Slack, browsers, custom tooling).

## Definition

An MCP server exposes tools (and data) to Claude over a standard protocol; you declare servers in
config and Claude can then call their tools. **Context cost:** at session start only the **tool
names** from connected servers load; full JSON schemas stay deferred until a tool is used, and tool
search keeps idle MCP tools cheap. MCP connections can fail silently mid-session — if Claude stops
being able to use a tool it had, check `/mcp`. MCP is an open protocol, so the *servers* are
reusable across MCP-aware tools even though the *config file* differs per tool. (Pair an MCP server
with a [skill](skills.md) that teaches Claude how to use it well — schema, query patterns, which
table for what.)

## Scope

[Override-by-name](../glossary.md) — on a server-name clash: **local > project > user** (plugin
and managed servers also merge in).

| Scope | Location | Shared with |
|-------|----------|-------------|
| user | `~/.claude.json` | just you, all projects |
| project | `.mcp.json` at the repo root | the team (committed) |
| local (per-project) | `~/.claude.json` (per-project section) | just you, this repo |
| managed | `managed-mcp.json` in the managed-policy directory | everyone in the org |
| plugin | a plugin's `.mcp.json` | where the plugin is enabled |
| subagent | a subagent's `mcpServers` frontmatter (server names or inline `.mcp.json`-schema defs) | only that subagent — keeps the tools out of the main conversation's context |

Not loaded from `--add-dir` directories.

## Configure

`.mcp.json` entries use the standard MCP server schema (`stdio`, `http`, `sse`, `ws`), keyed by
server name. **No hardcoded tokens** — it's committed; use OAuth or env-var-referenced secrets.

| Invoke | What it does |
|--------|--------------|
| `/mcp` **[built-in]** | Add, remove, reconnect, and authenticate (OAuth) MCP servers; shows connection status and per-server token cost. |
| `claude mcp add <name> …` **[built-in CLI]** | Add a server from the terminal. |
| `/plugin` **[built-in]** | Install MCP servers bundled with a plugin. |
| `mcpServers:` frontmatter | Define a server scoped to a single subagent (see [`subagents.md`](subagents.md)). |

## Validate

| Invoke | What it does |
|--------|--------------|
| `/mcp` **[built-in]** | Lists configured servers with connection / OAuth status and **token cost per server** — the way to spot dead or expensive servers. Reconnect dead ones here. |
| `/context` **[built-in]** | Shows how much of the window MCP tool names are consuming, in the overall picture. |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Recommends MCP servers worth adding for the codebase. |
| `claude-code-guide` agent **[plugin]** | Answers MCP config questions and sanity-checks the file. |
| `harness-optimizer` agent **[plugin]** | Reviews MCP config as part of a harness audit. |

## Improve

**Must**
- No hardcoded tokens — `.mcp.json` is committed. Use OAuth or env-var-referenced secrets.
- Only list servers you actually use; remove the rest — a dead entry still costs a startup connection attempt, and tool names load every session.

**Should**
- Prefer servers with small, well-scoped tool surfaces; drop noisy ones.
- Pin versions; vet or self-host critical servers; re-audit periodically.
- Use `/mcp` to spot and reconnect dead servers.
- Need a server only occasionally? Add it per-project where it's used, not globally. For subagent-only use, define it in that subagent's `mcpServers` frontmatter so its tool descriptions don't burden the main conversation.

| Limit | Value | Note |
|-------|-------|------|
| Connected servers | as few as you need (single digits) | tool names load every session |
| Tools per server | prefer < ~20 | 50+ tools is heavy; pick a narrower server or scope it |
| Context cost | low until a tool is used | tool names at start; full schemas deferred; tool search keeps idle tools cheap |
| Secrets in `.mcp.json` | zero | OAuth or env-var references only |

## Sources

- MCP (config locations, scope hierarchy & precedence, tool search) — <https://code.claude.com/docs/en/mcp>
- Extend Claude Code (MCP vs Skill; context cost) — <https://code.claude.com/docs/en/features-overview>
- Settings (`managed-mcp.json`, allowlists) — <https://code.claude.com/docs/en/settings> · Subagents (`mcpServers` frontmatter) — <https://code.claude.com/docs/en/sub-agents>
- Commands (`/mcp`) — <https://code.claude.com/docs/en/commands>
