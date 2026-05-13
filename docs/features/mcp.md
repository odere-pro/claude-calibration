# MCP

Model Context Protocol servers — external processes that expose tool-sets to Claude. Configured
via `.mcp.json` (project), `~/.claude.json` `mcpServers` (user), `managed-mcp.json` (enterprise),
or a subagent's `mcpServers:` frontmatter (agent-scoped).

## Definition

- **Files** — `.mcp.json` at the project root; `mcpServers` block inside `~/.claude.json`.
- **What it does** — declares one or more servers with a `command`/`args`/`env`/`url` and an
  optional `headers` block; Claude connects on session start.

## Scope

User · Project · Per-agent (via subagent `mcpServers:` frontmatter). Each server adds its
tool-set's metadata to the standing context — high cost if the server exposes many tools.

## Configure

- Tokens and API keys via `${ENV_VAR}` substitution, never literal in `.mcp.json`.
- If a server is used by exactly one agent, move it to that agent's `mcpServers:` frontmatter
  (don't pay the cost for every session).
- Pair a heavy MCP server with a wrapper **skill** (4-layer pattern) so the skill's
  `disable-model-invocation` keeps the server's surface out of the standing context.

## Validate

- `/mcp` lists servers and per-server tool-set cost.
- `bash skills/calibrate-mcp/scripts/lint.sh <.mcp.json | agent.md>` — `mcp:secret-in-mcpjson`,
  `:no-skill-pair`, `:over-broad-surface`, `:dead-server-heuristic`, `:subagent-only-in-shared`,
  `:invalid-json`.

## Improve

| Must                          | Should                                            | Limit                |
| ----------------------------- | ------------------------------------------------- | -------------------- |
| No literal tokens in JSON     | Wrap heavy servers with a `disable-model-invoke`  | server tool count    |
| Valid JSON                    | skill (4-layer)                                   | per server reviewed  |
|                               | Move agent-only servers into agent frontmatter    |                      |

## Sources

- MCP — <https://code.claude.com/docs/en/mcp>
