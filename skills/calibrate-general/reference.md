# General / cross-cutting calibration reference

> Source of truth: [`docs/general-setup.md`](../../docs/general-setup.md) (esp. the **Improve →
> Always-on checklist** and the **Context cost** table).

## The always-on checklist (from general-setup.md)

- `CLAUDE.md` < ~200 lines, concrete, secret-free; bulk content in `.claude/rules/` (path-scoped).
- `AGENTS.md` (if present) is imported from `CLAUDE.md`.
- Permissions allowlist covers safe-and-frequent; nothing destructive blanket-allowed; never
  `--dangerously-skip-permissions`.
- No secrets in any committed file.
- Subagents have explicit minimal `tools`, sharp single-purpose descriptions, the cheapest capable
  model.
- Active skills are non-overlapping with key-use-case-first descriptions (well under 1,536 chars);
  bodies under ~500 lines; unused → `skillOverrides` off / name-only / deleted.
- Hooks: sub-second on tool events; heavy on `Stop`; narrowly matched; locally sourced; ordered
  cheap→expensive; use `exit 2` to block.
- `.mcp.json` lists only servers in active use; tokens via OAuth/env.
- Only plugins in active use enabled.
- Anything the team needs is committed; nothing critical lives only in someone's `~/.claude/`.
- Periodic audit: `/doctor` → `/context` → `/skills` (token sort) → `/mcp` (cost) → harness audit.
- Don't work in the last ~20% of the context window — `/compact` or start fresh; route model to task
  complexity.

## Context-cost model

| Feature | When it loads | What loads | Cost |
|---|---|---|---|
| `CLAUDE.md` / unconditional rules | session start | full content | every request |
| Skills | session start + on use | descriptions every request; full body when invoked (then sticks) | low (description) → 0 with `disable-model-invocation: true` |
| MCP servers | session start | tool *names*; schemas on demand | low until used |
| Subagents | when spawned | name+description in routing context | isolated work |
| Hooks | on trigger | nothing | 0 unless they return output |
| Plugins | (sum of contained features) | sum of skills/agents/MCP/hooks | multiplies the above |

**Rule of thumb: if it's loaded but unused, delete it.**

## 3-vs-4-layer call

A capability is **3-layer** when it's self-contained: skills → agents → entry point, with the work
performed by Claude using built-in tools. A capability is **4-layer** when CLI / MCP integration is
its core purpose: a CLI tool or MCP server is wrapped by a skill that documents the recipes / schema.
Each capability should be evaluated against the right pattern — a heavy CLI-shelling skill that's
"3-layer" is leaving capability on the table; an MCP server with no wrapper skill is the docs' own
anti-pattern.

When the same external CLI/MCP is touched repeatedly across the setup → promote (planner emits a
`create` row for the wrapper, routed through `calibrate-skills`'s wrapper templates).

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `general:context-budget-overflow` | Estimated total always-on cost (CLAUDE.md + unconditional rules + active skill descriptions + MCP tool-name count + subagent name/desc) > a heuristic threshold (e.g. > 5,000 tokens with a Sonnet 200K window — flag earlier than `/doctor` would) | MEDIUM |
| `general:nested-claude-md-conflict` | Two CLAUDE.md files at different levels say contradictory things on the same topic | MEDIUM |
| `general:settings-precedence-surprise` | A project setting is silently overridden by a managed setting | LOW |
| `general:no-gitignore-for-claude-local` | `.gitignore` doesn't cover `CLAUDE.local.md` and/or `.claude/settings.local.json` and/or `.claude/calibration/` | LOW |
| `general:must-rule-with-no-hook` | CLAUDE.md or rules contain "always do X" / "never do Y" lines but no hooks block exists in the project (cross-feature; same as `claude-md:must-rule-with-no-hook` but rolled up) | MEDIUM |
| `general:diagnostics-ask` | (Always emitted) Reminder that `/doctor`/`/context`/`/skills`/`/mcp` outputs should be pasted into the report for live numbers | INFO |
