# MCP calibration reference

> Source of truth: [`docs/features/mcp.md`](../../docs/features/mcp.md).

## Must

- No literal tokens in `.mcp.json` (or any committed `mcpServers` block). Use `${ENV_VAR}` only.
- Valid JSON.

## Should

- Pair each server with a wrapper skill (`disable-model-invocation: true`) — the 4-layer pattern
  keeps the server's tool-set out of the standing context.
- Move agent-only servers out of `.mcp.json` and into the owning subagent's `mcpServers:`
  frontmatter.
- Review every server's tool count — anything over ~50 tools should be wrapper-gated.

## Limits

| Aspect             | Recommended                                          |
| ------------------ | ---------------------------------------------------- |
| Tool count per server | ≤ ~50 (heuristic; otherwise wrap in a skill)      |
| Secrets in `.mcp.json` | zero — use `${ENV_VAR}` substitution             |
| Servers without a skill pair | zero for heavy servers                       |

## Pattern signatures

| Signature                     | Trigger                                                                                       | Default severity |
| ----------------------------- | --------------------------------------------------------------------------------------------- | ---------------- |
| `mcp:secret-in-mcpjson`       | A literal token-shaped string in `.mcp.json` (or a committed `mcpServers` block)              | **CRITICAL**     |
| `mcp:invalid-json`            | The file isn't valid JSON                                                                     | HIGH             |
| `mcp:over-broad-surface`      | A server with a high known tool count (heuristic: 50+ if metadata is available)               | MEDIUM           |
| `mcp:no-skill-pair`           | A server whose name has no matching wrapper skill                                              | LOW              |
| `mcp:dead-server-heuristic`   | A server in config that hasn't appeared in recent transcripts (best-effort)                   | LOW              |
| `mcp:subagent-only-in-shared` | A server appears in `.mcp.json` but is used by exactly one subagent — move to that agent     | LOW              |
