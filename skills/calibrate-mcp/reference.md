# MCP calibration reference

> Source of truth: [`docs/features/mcp.md`](../../docs/features/mcp.md).

## Must

- **No hardcoded tokens** in `.mcp.json` (committed). Use OAuth or `${ENV_VAR}` references.
- Only list servers actually in use. Dead/unused entries cost a startup connection attempt and load
  tool names every session.

## Should

- Prefer servers with small, well-scoped tool surfaces; investigate alternatives at 50+ tools.
- Pin versions; vet or self-host critical servers; periodic re-audit (`/mcp` for cost).
- Use `/mcp` to spot and reconnect dead servers — silently disconnected → Claude fails at "available"
  tools.
- Add a server only at the scope where it's used: per-project (`.mcp.json`); user-level for everyday;
  **subagent-only via `mcpServers:` frontmatter** (keeps tool descriptions out of the main window).
- **Pair every server with a skill** that documents schema + common queries + pitfalls (the docs'
  recommendation; the 4-layer pattern). See `calibrate-skills/templates/mcp-wrapper.tmpl`.

## Limits

| Aspect | Recommended |
|---|---|
| Connected servers | as few as needed (single digits) |
| Tools per server | < ~20; investigate at 50+ |
| Secrets in committed `.mcp.json` | zero |

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `mcp:secret-in-mcpjson` | A literal token-shaped string in `.mcp.json` (or in a committed `mcpServers` block) | **CRITICAL** |
| `mcp:no-skill-pair` | A server in `.mcp.json` whose name has no matching skill (`/<server-name>` skill or `mcp__<server>` references in any skill body) | LOW |
| `mcp:over-broad-surface` | A server with a high known tool count (heuristic: 50+ if metadata available; otherwise flag a wrapper-skill-without-Tool-reference table) | MEDIUM |
| `mcp:dead-server-heuristic` | A server in config that hasn't appeared in `~/.claude/projects/*/transcripts/*.jsonl` for ≥ 30 days (best-effort) | LOW |
| `mcp:subagent-only-in-shared` | A server appears used by exactly one subagent's body — it should move to that agent's `mcpServers:` frontmatter | LOW |
| `mcp:invalid-json` | The file isn't valid JSON | HIGH |
