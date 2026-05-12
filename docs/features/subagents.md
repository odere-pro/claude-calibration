[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Subagents

A Markdown file with YAML frontmatter that defines a specialized worker — its own context window,
system prompt, tool access, and model. Claude delegates a matching task to it; it works
independently and returns a summary.

## Definition

A subagent file = YAML frontmatter (config) + a Markdown body that is the **system prompt** (the
subagent receives only that plus basic environment details — not the full Claude Code system
prompt). It runs in an **isolated context window**: the heavy intermediate work (search results,
logs, file contents) stays in the subagent; only the result returns. **Context cost:** the
subagent's name + description sit in the orchestrator's context for routing decisions; its actual
work is isolated. Use one for a side task that would flood the main conversation; define a custom
one when you keep spawning the same kind of worker. Built-in subagents: `Explore`, `Plan`,
`general-purpose`. (For *independent* sessions that talk to each other, that's **Agent teams** —
experimental; see the [official docs](https://code.claude.com/docs/en/agent-teams).)

## Scope

[Override-by-name](../glossary.md) — on a name clash the higher-priority scope wins.

| Priority | Scope | Location | How to create |
|----------|-------|----------|---------------|
| 1 (highest) | managed | `agents/` in the [managed-settings directory](https://code.claude.com/docs/en/settings) | admin deploys it |
| 2 | session | `--agents` CLI flag (JSON, same fields; `prompt` = the body) | pass at launch |
| 3 | project | `.claude/agents/` (discovered by walking up from cwd; **not** from `--add-dir`) | `/agents` or hand-write |
| 4 | user | `~/.claude/agents/` | `/agents` or hand-write |
| 5 (lowest) | plugin | a plugin's `agents/` | installed with the plugin |

The effective set is the union. Plugin subagents ignore the `hooks`, `mcpServers`, and
`permissionMode` frontmatter fields (copy the file into `.claude/agents/` if you need them).

## Configure

```yaml
---
name: code-reviewer            # required: lowercase letters + hyphens, unique within scope; filename need not match
description: Reviews code for quality and best practices   # required: when Claude should delegate to it
tools: Read, Glob, Grep        # optional — OMITTED ⇒ inherits ALL tools (incl. MCP)
model: sonnet                  # optional — sonnet | opus | haiku | <full model id> | inherit (default: inherit)
---
You are a senior code reviewer. … (the body is the system prompt)
```

Only `name` and `description` are required. All fields:

| Field | Notes |
|-------|-------|
| `name`, `description` | required (see above); `name` is what hooks receive as `agent_type` |
| `tools` | allowlist; **omitted ⇒ inherits all tools** including MCP — restrict to the minimum |
| `disallowedTools` | denylist; applied *before* `tools`; a tool in both is removed |
| `model` | `sonnet`/`opus`/`haiku`/full id/`inherit`; default `inherit`. (Resolution: `CLAUDE_CODE_SUBAGENT_MODEL` env → per-invocation `model` → frontmatter → main conversation) |
| `permissionMode` | `default`/`acceptEdits`/`auto`/`dontAsk`/`bypassPermissions`/`plan` (ignored for plugin subagents) |
| `maxTurns` | cap on agentic turns |
| `skills` | skills to **preload fully** into the subagent's context at startup (it can still invoke other skills via the Skill tool) |
| `mcpServers` | servers available only to this subagent — server names or inline `.mcp.json`-schema definitions. Defining a server here keeps its tool descriptions out of the main conversation (ignored for plugin subagents) |
| `hooks` | lifecycle hooks scoped to this subagent (ignored for plugin subagents) |
| `memory` | `user`/`project`/`local` — enables cross-session auto memory for this subagent |
| `background` | `true` → always run as a background task |
| `effort` | effort override while this subagent is active |
| `isolation: worktree` | run in a temporary git worktree (auto-cleaned if it makes no changes) |
| `color` | display colour in the task list / transcript |
| `initialPrompt` | auto-submitted first user turn when this agent runs as the main session agent (`--agent` / the `agent` setting) |

| Invoke | What it does |
|--------|--------------|
| `/agents` **[built-in]** | Create and edit subagent definitions interactively (pick scope, generate the identifier/description/system prompt, select tools and model). |
| `--agents '<json>'` (CLI) | Define session-scoped subagents at launch (same fields; `prompt` = the body). |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Recommends which subagents to add for the codebase. |

## Validate

| Invoke | What it does |
|--------|--------------|
| `/agents` **[built-in]** | Lists the effective subagents (and which scope each came from) so you can inspect and edit them. |
| `harness-optimizer` agent **[plugin]** | Reviews subagent definitions — tools, model, prompt scope — as part of a harness audit. |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Spots gaps and overlaps in the subagent set. |
| `claude-code-guide` agent **[plugin]** | Answers "is this definition valid / how should X be set". |

## Improve

**Must**
- Restrict `tools` (or use `disallowedTools`) — omitting `tools` inherits *everything*, including MCP; extra tools mean more schema in the subagent's context and more ways to go wrong.
- No name collisions you didn't intend (precedence: managed > `--agents` > project > user > plugin).

**Should**
- Write a sharp, single-purpose `description` with strong routing cues (e.g. "Use PROACTIVELY when …") so the right agent fires.
- Pick the cheapest capable `model`: Haiku for narrow reviewers/workers, Sonnet for orchestration, Opus rarely.
- Keep the system-prompt body focused (≲ ~150–200 lines); don't paste the codebase into it.
- Consolidate near-duplicate agents instead of accumulating them.
- Run independent subagents in parallel (one message, multiple Agent calls).
- Put a subagent-only MCP server in that agent's `mcpServers` frontmatter, not `.mcp.json`, so its tool descriptions don't burden the main conversation.

| Limit | Value | Note |
|-------|-------|------|
| Required frontmatter | `name`, `description` | only these two |
| `name` | lowercase letters + hyphens, unique within scope | filename need not match |
| `tools` | restrict explicitly | omitted ⇒ inherits all tools incl. MCP |
| `model` | default `inherit` | choose the cheapest capable model deliberately |
| Body (system prompt) | keep focused | not the full Claude Code prompt; just this body + env |

## Sources

- Subagents (scopes, precedence, full frontmatter, tools/model behavior, built-in agents) — <https://code.claude.com/docs/en/sub-agents>
- Extend Claude Code (Skill vs Subagent; Subagent vs Agent team; context cost) — <https://code.claude.com/docs/en/features-overview>
- Commands (`/agents`) — <https://code.claude.com/docs/en/commands> · Tools reference — <https://code.claude.com/docs/en/tools-reference>
