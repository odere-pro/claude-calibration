# Subagents calibration reference

> Source of truth: [`docs/features/subagents.md`](../../docs/features/subagents.md). This file is the
> calibration rubric — kept in sync by `/plugin-update`.

## Must

- **Restrict `tools`** (or use `disallowedTools`). Omitting `tools:` makes the subagent inherit
  *every* tool, including all MCP tools — almost always too broad.
- No name collisions you didn't intend. Precedence: managed > `--agents` > project > user > plugin.

## Should

- Sharp, single-purpose `description` with strong routing cues ("Use PROACTIVELY when …", "MUST BE
  USED for …") so the right subagent fires and others don't.
- Pick the cheapest capable `model` deliberately: **Haiku** for narrow reviewers/workers, **Sonnet**
  for orchestration, **Opus** only when the reasoning genuinely needs it. Default `inherit` may
  overspend.
- Body **focused (≲ ~150–200 lines)** — it's the only instruction the subagent gets; no codebase dumps.
- Consolidate near-duplicate subagents (each name+description sits in routing context).
- Run independent subagents in parallel when work is genuinely independent (one message, multiple
  Agent calls).
- Subagent-only MCP server → define in that subagent's `mcpServers` frontmatter, **not** `.mcp.json`,
  so its tool descriptions stay out of the main window.
- Use `isolation: worktree` for change-heavy exploratory work; `maxTurns` to bound runaways;
  `skills:` to preload exactly the reference material the subagent needs.

## Limits

| Aspect | Recommended | Notes |
|---|---|---|
| `name` | lowercase letters + hyphens; unique within scope | the `agent_type` hooks see |
| `description` | specific, single-purpose, with trigger cues | routing key — sits in main context |
| `tools` | minimum explicit allowlist | omitted = inherits all (incl. MCP) |
| `model` | explicit choice (haiku/sonnet/opus) | default `inherit` is rarely right |
| Body length | ≲ 150–200 lines | the only instruction the subagent gets |
| `maxTurns` | bound for risky/long-running work | runaway protection |

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
| `subagent:bare-mcp-in-mcpjson` | Subagent uses an MCP server defined in `.mcp.json` that no other agent uses → should move into the subagent's `mcpServers` frontmatter | LOW |
| `subagent:plugin-ignored-frontmatter` | Plugin-shipped subagent has `hooks` / `mcpServers` / `permissionMode` (these are silently ignored for plugin agents) | LOW |
