---
name: calibrate-mcp
description: >-
  Audits MCP server configuration across every layer Claude Code reads — project `.mcp.json`,
  user `~/.claude.json`'s `mcpServers` block, and per-agent `mcpServers:` frontmatter inside
  `.claude/agents/*.md`. Flags literal tokens in committed JSON (the high-impact security
  finding), servers with no paired wrapper skill (always-on tool-set cost), heuristically
  over-broad surfaces (50+ tools), dead servers no longer in use, servers used by exactly one
  subagent that should move into that agent's frontmatter, and invalid JSON. Invoked by the
  calibration orchestrator (`/calibrate`) and standalone via
  `/claude-calibration:calibrate-mcp`.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(bash *), Edit(.mcp.json), Write(.mcp.json), Edit(.claude/agents/*.md), Write(.claude/agents/*.md)
---

# calibrate-mcp — per-feature bundle

You audit and tune MCP configuration. You receive one of two kinds of work:

- **Direct invocation** (`/claude-calibration:calibrate-mcp`) — audit everything, report findings,
  propose fixes inline. The user drives the conversation.
- **Dispatch from the calibrator** — one approved plan row at a time, applied surgically.

In both cases the workflow is the same; only the framing differs.

## 1. Enumerate

```bash
bash <BUNDLE>/scripts/enumerate.sh "$PROJECT_DIR"
```

Yields TSV `scope\tpath`. Scopes:

- `project` — `<PROJECT_DIR>/.mcp.json`
- `user` — `~/.claude.json` (best-effort; the `mcpServers` block lives inside)
- `agent` — `.claude/agents/*.md` files declaring `mcpServers:` in frontmatter (user + project)

## 2. Lint

```bash
bash <BUNDLE>/scripts/lint.sh <path …>
```

Yields TSV `path\tsignature\tseverity\tdetail`. The signatures this bundle owns
(see `reference.md`):

- `mcp:invalid-json` (HIGH)
- `mcp:secret-in-mcpjson` (CRITICAL)
- `mcp:no-skill-pair` (LOW)
- `mcp:over-broad-surface` (MEDIUM)
- `mcp:dead-server-heuristic` (LOW) — best-effort; skipped without transcript access
- `mcp:subagent-only-in-shared` (LOW) — surfaced when a server appears in `.mcp.json` and exactly
  one subagent's body references it

## 3. Fix — `kind: edit` rows

For each finding, the remediation pattern:

- `mcp:secret-in-mcpjson` → see `examples/secret-in-mcpjson/{before,after}.md`. Replace the literal
  token with `${ENV_VAR}` substitution, set the env var locally, **rotate the exposed credential**.
- `mcp:no-skill-pair` → scaffold a wrapper skill at `skills/<server-name>/SKILL.md` (4-layer
  pattern: skill with `disable-model-invocation: true` wrapping the MCP server).
- `mcp:over-broad-surface` → audit the server's tool-set; either trim via the server's own config
  or move it behind a `disable-model-invocation` wrapper skill so the cost is on-demand.
- `mcp:dead-server-heuristic` → confirm with the user, then remove from the config.
- `mcp:subagent-only-in-shared` → move the server config from `.mcp.json` into that subagent's
  `mcpServers:` frontmatter.
- `mcp:invalid-json` → fix the parse error reported in the detail.

## 4. Create — `kind: create` rows

Recurrences this bundle's _companion_ (calibrate-skills) handles (per `rules/dispatch.md`):

- `mcp:no-skill-pair` ×N for the same server → calibrate-skills scaffolds the wrapper skill.

This bundle has no `kind: create` recurrence of its own.

## 5. Verify

After every edit, re-run `bash <BUNDLE>/scripts/lint.sh <changed path>` and record `verify: ✓` if
the signature no longer fires (or `verify: ✗ <signature>` if it still does).

## Hard rules

- Never write a literal token into `.mcp.json` or a committed `mcpServers` block. Always use
  `${ENV_VAR}` substitution.
- Don't move a server into a subagent's frontmatter unless exactly one subagent uses it.
- Don't reformat unrelated keys in a `.mcp.json` when applying a fix.
