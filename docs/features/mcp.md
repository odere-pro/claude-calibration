[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# MCP

Model Context Protocol — the open standard for connecting Claude Code to external services and tools
(databases, Slack, browsers, custom tooling).

## Definition

An MCP server exposes tools (and data) to Claude over a standard protocol; you declare servers in
config and Claude can then call their tools to read external data or take actions. **Context cost:**
at session start only the **tool _names_** from connected servers load; full JSON schemas stay
deferred until a tool is actually used, and MCP _tool search_ is on by default so idle servers
consume minimal context. The risk is _quantity_ — many connected servers, or servers with huge tool
catalogues, add up. MCP connections can also fail silently mid-session: if a server disconnects its
tools disappear without warning and Claude may try to use one that's gone — if you notice that,
check `/mcp`. MCP is an open protocol, so the _servers_ are reusable across MCP-aware tools even
though the _config file_ differs per tool. (Pair an MCP server with a [skill](skills.md) that
teaches Claude how to use it well — your schema, common query patterns, which table for what.)

## Scope

[Override-by-name](../glossary.md) — on a server-name clash: **local > project > user** (plugin and
managed servers also merge in). The effective set is the union.

| Scope               | Location                                                                                       | Shared with                                                                                  |
| ------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| user                | `~/.claude.json`                                                                               | just you, all projects                                                                       |
| project             | `.mcp.json` at the repo root                                                                   | the team (committed)                                                                         |
| local (per-project) | `~/.claude.json` (per-project section)                                                         | just you, this repo                                                                          |
| managed             | `managed-mcp.json` in the managed-policy directory (same locations as `managed-settings.json`) | everyone in the org                                                                          |
| plugin              | a plugin's `.mcp.json`                                                                         | where the plugin is enabled                                                                  |
| subagent            | a subagent's `mcpServers` frontmatter — server names or inline `.mcp.json`-schema defs         | only that subagent — and its tool descriptions stay _out of_ the main conversation's context |

Not loaded from `--add-dir` directories.

## Configure

`.mcp.json` entries use the standard MCP server schema (`stdio`, `http`, `sse`, `ws`), keyed by
server name. **No hardcoded tokens** — `.mcp.json` is committed; use OAuth (authenticate via `/mcp`)
or env-var-referenced secrets.

| Invoke                                       | What it does                                                                                                                                                                                                 |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/mcp` **[built-in]**                        | Manages MCP server connections — add or remove servers, authenticate via OAuth, reconnect dropped ones — and shows each server's connection status and **token cost**. The control panel for everything MCP. |
| `claude mcp add <name> …` **[built-in CLI]** | Adds an MCP server from the terminal (writes it to the relevant config); useful in scripts and one-off setup.                                                                                                |
| `/plugin` **[built-in]**                     | Installs MCP servers that come bundled in a plugin (the plugin's `.mcp.json`).                                                                                                                               |
| `mcpServers:` frontmatter                    | Defines a server scoped to a single subagent — see [`subagents.md`](subagents.md); keeps the tools out of the main conversation.                                                                             |

## Validate

| Invoke                                                          | What it does                                                                                                                                                                                                                                             |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/mcp` **[built-in]**                                           | Lists every configured server with connection / OAuth status and **token cost per server** — the way to spot dead servers (still costing a startup connection attempt) and expensive ones (big tool catalogues). Reconnect or re-authenticate from here. |
| `/context [all]` **[built-in]**                                 | Shows how much of the context window MCP tool names are taking, in the overall picture — the cross-feature view.                                                                                                                                         |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Looks at the codebase and recommends MCP servers worth adding for the external systems it sees referenced.                                                                                                                                               |
| `claude-code-guide` agent **[plugin]**                          | Answers MCP config questions (schemas, transports, OAuth) and sanity-checks the file.                                                                                                                                                                    |
| `harness-optimizer` agent **[plugin]**                          | Reviews the MCP config as part of a whole-harness audit — flags unused servers and oversized tool surfaces.                                                                                                                                              |

## Improve

**Must**

- No hardcoded tokens in `.mcp.json` — it's committed. Use OAuth or env-var-referenced secrets.
- Only list servers you actually use — and remove the rest. A dead or unused entry still costs a startup connection attempt, and its tool names load into context every session.

**Should**

- Prefer servers with small, well-scoped tool surfaces; if a server exposes 50+ tools, see whether a narrower server (or a scoped configuration of the same one) covers your need; drop chatty ones.
- Pin versions; vet or self-host critical servers; re-audit the list periodically (`/mcp` for cost).
- Use `/mcp` to spot and reconnect dead servers — a silently-disconnected server makes Claude fail at a tool it "should" have.
- Add a server only at the scope where it's used — per-project (`.mcp.json`) for project-specific ones, user-level (`~/.claude.json`) for everyday ones; for a server only one subagent needs, define it in that subagent's `mcpServers` frontmatter so its tool descriptions don't burden the main conversation.
- Pair a server with a skill documenting how to use it well — fewer flailing tool calls.

| Aspect                 | Recommendation                                                                                        | Why                                                                     |
| ---------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Connected servers      | as few as you need (single digits)                                                                    | tool names from every connected server load every session               |
| Tools per server       | prefer < ~20; investigate alternatives at 50+                                                         | big tool catalogues add up across servers                               |
| Secrets in `.mcp.json` | zero — OAuth or env-var references only                                                               | the file is committed                                                   |
| Scope                  | per-project for project-specific; user-level for everyday; `mcpServers` frontmatter for subagent-only | a subagent-only server in `.mcp.json` taxes the main window for nothing |
| Dead servers           | remove or reconnect (`/mcp`)                                                                          | still costs a startup attempt; makes Claude fail at "available" tools   |
| Versions / trust       | pin; vet or self-host critical ones; re-audit                                                         | supply-chain hygiene                                                    |
| Context cost           | low until a tool is used (names at start; schemas deferred; tool search keeps idle tools cheap)       | the cost scales with _number_ of servers/tools, so prune                |
| Usability              | pair with a skill that documents the server                                                           | reduces flailing tool calls                                             |

## Sources

- MCP — config locations, scope hierarchy & precedence, transports, OAuth, MCP tool search — <https://code.claude.com/docs/en/mcp>
- Extend Claude Code — MCP vs Skill; context cost / reliability note — <https://code.claude.com/docs/en/features-overview>
- Settings (`managed-mcp.json`, MCP allowlists) — <https://code.claude.com/docs/en/settings> · Subagents (`mcpServers` frontmatter) — <https://code.claude.com/docs/en/sub-agents>
- Commands (`/mcp`) — <https://code.claude.com/docs/en/commands>
