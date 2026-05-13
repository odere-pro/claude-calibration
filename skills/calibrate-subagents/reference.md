# Subagents calibration reference

> Source of truth: [`docs/features/subagents.md`](../../docs/features/subagents.md).

## Must

- `name`, `description`, and **`tools:`** set in frontmatter. Omitting `tools:` inherits every
  MCP server in scope — the single biggest subagent footgun.
- `model:` set explicitly (don't rely on the `inherit` default — it silently uses the parent's
  Opus).
- Plugin-shipped subagents do NOT include `hooks:` / `mcpServers:` / `permissionMode:` — those
  fields are silently ignored at the plugin layer.

## Should

- `description` includes routing cues ("use when …", "after …", "before …") so Claude can route
  correctly.
- Body ≤ ~200 lines; the description does the routing, the body does the work.
- One agent per role; near-duplicate descriptions confuse routing.
- MCP servers only the agent uses go in its `mcpServers:` frontmatter, not in shared `.mcp.json`.

## Limits

| Aspect | Recommended |
|---|---|
| Body length | ≤ ~200 lines |
| `tools:` | explicit list (never omitted) |
| `model:` | explicit (`sonnet`, `haiku`, `opus`, or `inherit`) |
| Frontmatter on plugin-shipped agents | no `hooks` / `mcpServers` / `permissionMode` |

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `subagent:missing-name` | No `name` in frontmatter | HIGH |
| `subagent:missing-description` | No `description` in frontmatter | HIGH |
| `subagent:missing-tools` | `tools:` omitted → inherits ALL tools incl. MCP | HIGH |
| `subagent:body-over-200` | Body > 200 lines | MEDIUM |
| `subagent:default-inherit-model` | `model:` omitted (defaults to `inherit`) | MEDIUM |
| `subagent:vague-description` | Description lacks routing cues / trigger keywords | MEDIUM |
| `subagent:near-duplicate` | Two agents' descriptions overlap heavily (consolidation candidate) | MEDIUM |
| `subagent:bare-mcp-in-mcpjson` | Subagent uses an MCP server defined in `.mcp.json` that no other agent uses | LOW |
| `subagent:plugin-ignored-frontmatter` | Plugin-shipped subagent has `hooks` / `mcpServers` / `permissionMode` (silently ignored) | LOW |
