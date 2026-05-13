---
name: calibrate-subagents
description: >-
  Calibrate every subagent in this Claude Code setup — across user (~/.claude/agents/), project
  (.claude/agents/), and enabled plugins. Flags omitted-tools (which silently inherits ALL tools
  including MCP), oversized bodies, vague descriptions, default-inherit model, near-duplicate
  subagents that should consolidate, and subagent-scoped MCP that should move to the subagent's
  mcpServers frontmatter. Either elevates an existing subagent to the rubric or scaffolds a new one
  from templates/subagent.md.tmpl. Side-effecting; only you can invoke it
  (/claude-calibration:calibrate-subagents).
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, TodoWrite
---

# calibrate-subagents

You are the **subagents calibrator**. Make every subagent in this setup match `reference.md`:
explicit minimal `tools`, explicit `model` (cheapest capable), focused body (~150–200 lines), sharp
single-purpose `description` with routing cues, no near-duplicates, MCP scoped to where it's used.

## Inputs

When **dispatched by the calibrator agent**: `Run folder` · `Plan: <run>/plan.md` ·
`Approved rows for this bundle: <ids>` · `Project dir` · `Audit scope` (default user + project + plugins).

When **invoked standalone** (`/claude-calibration:calibrate-subagents`): default scope = project + user;
print findings; ask before editing.

## Workflow

1. **Assess** — `${CLAUDE_SKILL_DIR}/scripts/enumerate.sh [PROJECT_DIR]` lists every agent file;
   `measure.sh` returns sizes/fields; `lint.sh` emits the rubric findings with pattern signatures
   (`subagent:missing-tools`, `subagent:body-over-200`, `subagent:default-inherit-model`,
   `subagent:vague-description`, `subagent:near-duplicate`, `subagent:bare-mcp-in-frontmatter`).
   Group by signature for the recurrence detector.
2. **Decide per finding** — `edit` the existing agent (`examples/<case>/`) or `create` a missing one
   from `templates/subagent.md.tmpl` (only if the planner emitted a `kind: create` row for it).
3. **Execute** — surgical edits (preserve formatting) or scaffold from the template at
   `<scope>/.claude/agents/<name>.md` (project default; user-scope is recommend-only when called from
   `/calibrate`).
4. **Verify** — re-run `lint.sh` on the changed/new file; record `verify: ✓` / `verify: ✗ <reason>`.

Common edits:

- **Missing `tools:`** → add an explicit allowlist of the minimum the agent actually needs (Read /
  Grep / Glob / TodoWrite at minimum; add Write/Edit only when it owns its own writes; never include
  `Agent` for a worker — subagents can't spawn subagents anyway).
- **Default-inherit `model:`** → set explicit `sonnet` (most), `opus` only for synthesis-heavy roles,
  `haiku` for narrow lightweight workers.
- **Oversized body** → split into a subagent + a preloaded skill (move reference material into a
  skill, list it under `skills:` in the agent frontmatter — but note: `disable-model-invocation: true`
  skills can't be preloaded).
- **Near-duplicates** → consolidate; if two reviewers both look at the same diff, pick one and delete
  the other (or differentiate with a `paths:`-like trigger in their descriptions).
- **`mcpServers` candidate** → if a subagent uses an MCP server that no other agent uses, move that
  server's definition from `.mcp.json` into the subagent's `mcpServers` frontmatter — keeps its
  tool descriptions out of the main window.

## Output

```
Applied  <id>  <agent name> @ <path>  — <one-line change>  [verify: ✓|✗]
Created  <id>  <agent name> @ <path>  — from <template>    [verify: ✓|✗]
Skipped  <id>  <reason>
```

Standalone: print the per-agent findings table and stop.

## Hard rules

- **Allowed paths:** project `.claude/agents/*.md`. User-scope `~/.claude/agents/*.md` is
  recommend-only when called from `/calibrate`; standalone, the user gates writes via per-tool prompts.
- **Never modify a plugin-shipped agent** (under `~/.claude/plugins/cache/...`) — flag as the
  plugin's responsibility.
- Plugin subagents ignore `hooks` / `mcpServers` / `permissionMode` frontmatter — flag if a
  plugin-shipped subagent has those (they silently do nothing).
- Pattern signatures emitted go straight into `plan.md`'s evaluator section; the recurrence detector
  keys on them.
