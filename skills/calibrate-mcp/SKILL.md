---
name: calibrate-mcp
description: >-
  Calibrate every MCP server entry in this Claude Code setup — project .mcp.json, the user-scope and
  per-project mcpServers blocks in ~/.claude.json, subagent-scoped MCP in agents/*.md frontmatter,
  and (read-only) managed-mcp.json. Flags committed tokens, dead/unused servers, oversized tool
  surfaces (50+ tools), missing wrapper-skill pairings, and subagent-only servers misplaced in
  .mcp.json. Either elevates an entry (move to subagent frontmatter, swap a hardcoded token for
  $ENV reference, prune dead) or scaffolds a new entry from templates/mcp-entry.json.tmpl.
  Side-effecting; only you can invoke it (/claude-calibration:calibrate-mcp).
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, TodoWrite
---

# calibrate-mcp

You are the **MCP calibrator**. Make every MCP server entry match `reference.md`: no committed
tokens, only servers in active use, narrow surfaces, paired with a wrapper skill where that adds
value (the 4-layer pattern).

## Workflow

1. **Assess** — `${CLAUDE_SKILL_DIR}/scripts/enumerate.sh [PROJECT_DIR]` lists every MCP-bearing
   layer; `lint.sh` parses each + emits findings (`mcp:secret-in-mcpjson`, `mcp:no-skill-pair`,
   `mcp:over-broad-surface`, `mcp:dead-server-heuristic`, `mcp:subagent-only-in-shared`).
2. **Decide per finding** — `edit` (move a server to a subagent's `mcpServers` frontmatter; swap a
   hardcoded token for an env-var reference; prune a dead entry) or `create` (a new
   `templates/mcp-entry.json.tmpl`-based entry, or a paired wrapper skill via `calibrate-skills`).
3. **Execute** — surgical JSON edits. For tokens, swap to `${ENV_VAR}`-style references; for
   subagent-only servers, move the JSON block into the agent's frontmatter `mcpServers:`.
4. **Verify** — re-run `lint.sh` + `python3 -m json.tool <file>` for JSON validity.

## Output

```
Applied  <id>  <mcp file or agent>  — <change>  [verify: ✓|✗]
Created  <id>  <mcp entry @ file>  — from template  [verify: ✓|✗]
Skipped  <id>  <reason>
```

## Hard rules

- **Allowed paths:** project `.mcp.json`, project `.claude/agents/*.md` (`mcpServers:` frontmatter).
  User `~/.claude.json` is recommend-only when called from `/calibrate`.
- **No hardcoded tokens** — ever. Use OAuth (auth via `/mcp`) or env-var references only.
- A committed token is **CRITICAL** — surface immediately and recommend rotation.
- For an enforcement-creation row that pairs a server with a skill: delegate the create-half to
  `calibrate-skills` (it has `templates/mcp-wrapper.tmpl`).
