# Subagents

`.claude/agents/<name>.md` — specialised agents that run in their own context window, with their
own tools and model.

## Definition

- **Files** — one Markdown file per agent: YAML frontmatter + body (the system prompt).
- **Frontmatter** — `name`, `description`, `tools`, `model` (`opus | sonnet | haiku | inherit`),
  `maxTurns`, optionally `mcpServers`, `hooks` (project only; plugin-shipped agents have these
  silently ignored).

## Scope

User · Project · Plugin-shipped. Plugin agents appear under
`/agents` and can be invoked via the `Agent` tool.

## Configure

- **`tools:` MUST be set** — omitting it inherits all tools including every MCP server. This is
  the single biggest footgun.
- **`model:` should be explicit** — defaults to `inherit` (uses the parent's model, including
  Opus), which silently inflates cost.
- Body ≤ ~200 lines; routing detail in the `description`, not the body.

## Validate

- `/agents` lists registered agents.
- `bash skills/calibrate-subagents/scripts/lint.sh <agent.md>` — `subagent:missing-name`,
  `:missing-description`, `:missing-tools`, `:body-over-200`, `:default-inherit-model`,
  `:vague-description`, `:near-duplicate`, `:bare-mcp-in-mcpjson`,
  `:plugin-ignored-frontmatter`.

## Improve

| Must                                  | Should                                            | Limit         |
| ------------------------------------- | ------------------------------------------------- | ------------- |
| `tools:` declared explicitly          | `model:` declared explicitly (not `inherit`)      | body ≤ 200    |
| `name`, `description` present         | Description carries routing cues / trigger words  |               |
| No plugin-ignored frontmatter         | Move agent-only MCP servers from `.mcp.json`      |               |
|                                       | to the agent's `mcpServers:` frontmatter          |               |

## Sources

- Subagents — <https://code.claude.com/docs/en/sub-agents>
