---
name: calibrate-subagents
description: >-
  Audits every subagent `.md` across user / project / plugin-self / plugin-cache. Flags missing
  frontmatter (`name`, `description`, `tools`), the big footgun (no `tools:` → inherits ALL tools
  including every MCP server), bodies over 200 lines, omitted `model:` (defaults to `inherit`,
  silently inflates cost), vague descriptions Claude can't route on, near-duplicate descriptions
  that should be consolidated, bare-MCP usage that should move into the agent's `mcpServers:`
  frontmatter, and plugin-shipped agents that include `hooks:` / `mcpServers:` / `permissionMode:`
  frontmatter (silently ignored). Also produces the create-row companion when a recurring
  `subagent:missing-tools` pattern needs a write-guard hook. Invoked by the calibration
  orchestrator (`/calibrate`) and standalone via `/claude-calibration:calibrate-subagents`.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(bash *), Edit(.claude/agents/*.md), Edit(~/.claude/agents/*.md), Write(.claude/agents/*.md), Write(~/.claude/agents/*.md)
---

# calibrate-subagents — per-feature bundle

You audit and tune subagent `.md` files. You receive one of two kinds of work:

- **Direct invocation** (`/claude-calibration:calibrate-subagents`) — audit everything, report
  findings, propose fixes inline. The user drives the conversation.
- **Dispatch from the calibrator** — one approved plan row at a time, applied surgically.

In both cases the workflow is the same; only the framing differs.

## 1. Enumerate

```bash
bash <BUNDLE>/scripts/enumerate.sh "$PROJECT_DIR"
```

Yields TSV `scope\tpath`. Scope is `user` (`~/.claude/agents/*.md`), `project`
(`$PROJECT/.claude/agents/*.md`), or `plugin-self` (`$PROJECT/agents/*.md` when the project is
itself a plugin, plus plugin-cache best-effort).

The `plugin-self` (cached + project-plugin) rows honour the `CALIBRATION_PLUGIN_FILTER` env var, so
a calibration run scoped with `/calibrate --plugins …` only audits the requested plugins' subagents.

## 2. Lint

```bash
bash <BUNDLE>/scripts/lint.sh <path …>
```

Yields TSV `path\tsignature\tseverity\tdetail`. The signatures this bundle owns
(see `reference.md`):

- `subagent:missing-name` (HIGH)
- `subagent:missing-description` (HIGH)
- `subagent:missing-tools` (HIGH)
- `subagent:body-over-200` (MEDIUM)
- `subagent:default-inherit-model` (MEDIUM)
- `subagent:vague-description` (MEDIUM)
- `subagent:near-duplicate` (MEDIUM)
- `subagent:bare-mcp-in-mcpjson` (LOW)
- `subagent:plugin-ignored-frontmatter` (LOW)

## 3. Fix — `kind: edit` rows

For each finding, the remediation pattern is in `examples/<case>/`:

- `subagent:missing-name` / `:missing-description` → add the frontmatter field.
- `subagent:missing-tools` → see `examples/missing-tools/`: add an explicit `tools:` list. **This
  is the single biggest footgun** — without it, the subagent inherits every MCP server.
- `subagent:body-over-200` → trim; move detail into a `reference.md` or out of the subagent body.
- `subagent:default-inherit-model` → set `model:` explicitly (usually `sonnet` or `haiku`).
- `subagent:vague-description` → rewrite with routing words ("use when …", "after …", "before …").
- `subagent:near-duplicate` → consolidate the two subagents or rename to make routing unambiguous.
- `subagent:bare-mcp-in-mcpjson` → move the MCP server from shared `.mcp.json` into this subagent's
  `mcpServers:` frontmatter (companion work in `calibrate-mcp`).
- `subagent:plugin-ignored-frontmatter` → remove the silently-ignored frontmatter (`hooks:`,
  `mcpServers:`, `permissionMode:` — plugin-shipped subagents can't use these).

## 4. Create — `kind: create` rows

When the planner detects a recurrence that this bundle's signatures trigger (per
`rules/dispatch.md`), the create row is usually routed to a sibling bundle:

- **`subagent:missing-tools` ×N** → `calibrate-hooks` scaffolds a `PreToolUse` write-guard on
  `Edit(.claude/agents/*.md)` that fails if `tools:` is absent.

This bundle owns `templates/subagent.md.tmpl` for the case when a subagent is being recreated
from scratch — frontmatter has every field set explicitly.

## 5. Verify

After every edit or create, re-run `bash <BUNDLE>/scripts/lint.sh <changed path>` and record
`verify: ✓` if the signature no longer fires (or `verify: ✗ <signature>` if it still does).

## Hard rules

- `tools:` MUST be set explicitly — omitting it inherits every MCP server in scope.
- `model:` should be explicit — default `inherit` silently picks up the parent's Opus.
- Body ≤ ~200 lines; routing detail in the `description`, not the body.
- Plugin-shipped subagents must NOT include `hooks:` / `mcpServers:` / `permissionMode:` — those
  fields are silently ignored.
- Don't reformat unrelated content when applying a fix.
