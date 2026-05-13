[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Subagents

A Markdown file with YAML frontmatter that defines a specialized worker — its own context window,
system prompt, tool access, and model. Claude delegates a matching task to it; it works
independently and returns only a summary.

## Definition

A subagent file = YAML frontmatter (config) + a Markdown body that _is the system prompt_ (the
subagent receives only that plus basic environment details like the working directory — not the
full Claude Code system prompt). It runs in an **isolated context window**: the heavy intermediate
work — search results, logs, file contents — stays in the subagent, and only the result returns to
your main conversation. **Context cost:** the subagent's `name` + `description` sit in the main
conversation's context for routing decisions (cheap, like a skill description), and its actual work
is isolated (separate input/output tokens, doesn't bloat your main window). Use one for a side task
that would otherwise flood the main conversation; define a _custom_ one when you keep spawning the
same kind of worker with the same instructions. Built-in subagents: `Explore`, `Plan`,
`general-purpose`. (For _independent_ sessions that message each other, that's **Agent teams** —
experimental; see the [official docs](https://code.claude.com/docs/en/agent-teams).)

## Scope

[Override-by-name](../glossary.md) — on a name clash the higher-priority scope wins; the effective
set is the union.

| Priority    | Scope   | Location                                                                               | How to create             |
| ----------- | ------- | -------------------------------------------------------------------------------------- | ------------------------- |
| 1 (highest) | managed | `agents/` in the [managed-settings location](https://code.claude.com/docs/en/settings) | admin deploys it          |
| 2           | session | `--agents '<json>'` CLI flag (same fields; `prompt` = the body)                        | pass at launch            |
| 3           | project | `.claude/agents/` (discovered by walking up from cwd; **not** loaded from `--add-dir`) | `/agents` or hand-write   |
| 4           | user    | `~/.claude/agents/`                                                                    | `/agents` or hand-write   |
| 5 (lowest)  | plugin  | a plugin's `agents/`                                                                   | installed with the plugin |

Plugin subagents **ignore** the `hooks`, `mcpServers`, and `permissionMode` frontmatter fields —
copy the file into `.claude/agents/` (or add `permissions.allow` rules in settings) if you need
those.

## Configure

```yaml
---
name: code-reviewer # required: lowercase letters + hyphens, unique within scope; filename need not match
description: Reviews code for quality and best practices # required: when Claude should delegate to this subagent
tools: Read, Glob, Grep # optional — OMITTED ⇒ inherits ALL tools (incl. MCP); restrict to the minimum
model: sonnet # optional — sonnet | opus | haiku | <full model id> | inherit (default: inherit)
---
You are a senior code reviewer. … (the body is the system prompt)
```

Only `name` and `description` are required. All fields:

| Field                 | Notes                                                                                                                                                                                                                                                                     |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`, `description` | required (above); `name` is what hooks receive as `agent_type`; `description` is what Claude routes on, so make it specific with trigger cues ("Use PROACTIVELY when …")                                                                                                  |
| `tools`               | allowlist of tools the subagent may use; **omitted ⇒ it inherits _all_ tools** from the main conversation, including MCP tools — almost always too broad. Use `Agent(agent_type)` syntax to limit which subagents a `claude --agent` main thread can spawn                |
| `disallowedTools`     | denylist; applied _before_ `tools`; a tool in both is removed. Use this to "inherit everything except X, Y"                                                                                                                                                               |
| `model`               | `sonnet`/`opus`/`haiku`/full id/`inherit`; default `inherit`. Resolution order: `CLAUDE_CODE_SUBAGENT_MODEL` env → per-invocation `model` param → frontmatter → main conversation                                                                                         |
| `permissionMode`      | `default`/`acceptEdits`/`auto`/`dontAsk`/`bypassPermissions`/`plan` (ignored for plugin subagents)                                                                                                                                                                        |
| `maxTurns`            | cap on agentic turns before the subagent stops                                                                                                                                                                                                                            |
| `skills`              | skills to **preload fully** into the subagent's context at startup (the whole content, not just the description) — it can still invoke other project/user/plugin skills via the Skill tool                                                                                |
| `mcpServers`          | MCP servers available only to this subagent — server names referencing already-configured servers, or inline `.mcp.json`-schema definitions. Defining a server here keeps its tool descriptions **out of the main conversation's context** (ignored for plugin subagents) |
| `hooks`               | lifecycle hooks scoped to this subagent (ignored for plugin subagents)                                                                                                                                                                                                    |
| `memory`              | `user`/`project`/`local` — enables cross-session auto memory for this subagent                                                                                                                                                                                            |
| `background`          | `true` → always run this subagent as a background task                                                                                                                                                                                                                    |
| `effort`              | effort override (`low`…`max`, model-dependent) while this subagent is active                                                                                                                                                                                              |
| `isolation: worktree` | run the subagent in a temporary git worktree (an isolated copy of the repo; auto-cleaned if it makes no changes) — good for changes-heavy exploratory work                                                                                                                |
| `color`               | display colour in the task list / transcript                                                                                                                                                                                                                              |
| `initialPrompt`       | auto-submitted as the first user turn when this agent runs as the _main_ session agent (`--agent` / the `agent` setting); commands and skills in it are processed; prepended to any user prompt                                                                           |

| Invoke                                                          | What it does                                                                                                                                                                                                              |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/agents` **[built-in]**                                        | Opens the subagent manager — create a new subagent (it generates the identifier, description, and system prompt for you; you pick scope, tools, and model) or edit an existing one across project / user / plugin scopes. |
| `--agents '<json>'` (CLI)                                       | Define session-scoped subagents at launch — same fields as a file (use `prompt` for the body); useful for one-off or scripted runs.                                                                                       |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Looks at the codebase and recommends which subagents to add (and which existing ones overlap).                                                                                                                            |

## Validate

| Invoke                                                          | What it does                                                                                                                                              |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/agents` **[built-in]**                                        | Lists the effective subagents and which scope each one came from, so you can inspect the definitions, check name collisions, and edit them.               |
| `harness-optimizer` agent **[plugin]**                          | Reviews subagent definitions — `tools` breadth, `model` choice, prompt-body length and focus — as part of a whole-harness audit, and proposes tightening. |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Spots gaps and near-duplicates in the subagent set.                                                                                                       |
| `claude-code-guide` agent **[plugin]**                          | Answers "is this definition valid / how should this field be set".                                                                                        |

## Improve

**Must**

- Restrict `tools` (or use `disallowedTools`) — omitting `tools` makes the subagent inherit _everything_, including all MCP tools; that's more tool schema in its context, slower, and more ways to go wrong. Give it the minimum.
- No name collisions you didn't intend; know the precedence (managed > `--agents` > project > user > plugin).

**Should**

- Write a sharp, single-purpose `description` with strong routing cues (e.g. "Use PROACTIVELY when …") so the right subagent fires and others don't.
- Pick the cheapest capable `model` deliberately: Haiku for narrow reviewers/workers, Sonnet for orchestration, Opus only when the reasoning genuinely needs it (`model` defaults to `inherit`, which may be more than the task needs).
- Keep the system-prompt body **focused (≲ ~150–200 lines)** — it's the only instruction the subagent gets; don't paste the codebase into it.
- Consolidate near-duplicate subagents instead of accumulating them — each one's name+description is in the routing context.
- Run independent subagents in parallel (one message, multiple Agent calls) when the work is genuinely independent.
- Put a subagent-only MCP server in that subagent's `mcpServers` frontmatter, not `.mcp.json`, so its tool descriptions don't burden the main conversation.
- Use `isolation: worktree` for changes-heavy exploratory work, `maxTurns` to bound runaways, and `skills:` to preload exactly the reference material the subagent needs.

| Aspect               | Recommendation                                                              | Why                                                                |
| -------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Required frontmatter | `name`, `description` only                                                  | the rest is optional                                               |
| `name`               | lowercase letters + hyphens; unique within scope; filename need not match   | it's the `agent_type` hooks see                                    |
| `description`        | specific, single-purpose, with trigger cues ("Use PROACTIVELY when …")      | this is the routing key; it's in the main context                  |
| `tools`              | restrict explicitly to the minimum; or `disallowedTools` for "all except X" | omitted ⇒ inherits all tools incl. MCP — too broad                 |
| `model`              | choose the cheapest capable one (Haiku/Sonnet/Opus)                         | default `inherit` may overspend; subagents are where you save cost |
| Body (system prompt) | focused, ≲ ~150–200 lines; no codebase dumps                                | it's the _only_ instruction; just this + env                       |
| Duplication          | consolidate near-duplicates                                                 | each subagent's name+description sits in routing context           |
| Subagent-only MCP    | define in `mcpServers` frontmatter, not `.mcp.json`                         | keeps its tool descriptions out of the main window                 |
| Isolation / bounds   | `isolation: worktree` for change-heavy work; `maxTurns` to cap              | safe sandbox; runaway protection                                   |
| Preloaded skills     | `skills:` for exactly the reference the subagent needs                      | full content is injected at startup — keep the list tight          |
| Parallelism          | one message, multiple Agent calls for independent work                      | independent subagents run concurrently                             |

## Sources

- Subagents — scopes & precedence, the full frontmatter reference, `tools`/`disallowedTools`/`model` behavior, `--agents`, built-in subagents, model resolution, permission modes, worktree isolation — <https://code.claude.com/docs/en/sub-agents>
- Extend Claude Code — Skill vs Subagent; Subagent vs Agent team; context cost — <https://code.claude.com/docs/en/features-overview>
- Commands (`/agents`) — <https://code.claude.com/docs/en/commands> · Tools reference — <https://code.claude.com/docs/en/tools-reference>
