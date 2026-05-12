[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# CLAUDE.md

Plain-Markdown instruction files Claude loads into context at the start of every session.

## Definition

`CLAUDE.md` (plus `CLAUDE.local.md` and `.claude/rules/*.md` — see [`rules.md`](rules.md)) holds
persistent project/personal/org instructions: build commands, conventions, project layout, "always
do X" rules. It's delivered as a user message after the system prompt — *context*, not enforced
configuration; how specific and concise it is determines how reliably Claude follows it. **Context
cost:** full content, every request. Distinct from **auto memory** (notes Claude writes itself,
below). `AGENTS.md` is *not* read directly — see [importing `AGENTS.md`](#importing-agentsmd).

## Scope

[Additive](../glossary.md): all in-scope files are concatenated into context (closer = read last),
not overridden.

| Scope | Location | Shared with |
|-------|----------|-------------|
| managed | macOS `/Library/Application Support/ClaudeCode/CLAUDE.md` · Linux/WSL `/etc/claude-code/CLAUDE.md` · Windows `C:\Program Files\ClaudeCode\CLAUDE.md` (or the `claudeMd` key in `managed-settings.json`) | everyone on the machine; can't be excluded |
| user | `~/.claude/CLAUDE.md` | just you, all projects |
| project | `./CLAUDE.md` or `./.claude/CLAUDE.md` | the team (committed) |
| local | `./CLAUDE.local.md` (add to `.gitignore`; for git worktrees, import a file from `~/` instead) | just you, this repo |

**Load order:** managed → user (`~/.claude/CLAUDE.md` + `~/.claude/rules/*`) → project files found
by walking **up** the tree from cwd (filesystem-root → cwd, so the closest file is read **last**;
`CLAUDE.local.md` after `CLAUDE.md` at each level; `.claude/rules/*` at the priority of
`.claude/CLAUDE.md`). Subdirectory `CLAUDE.md` files *below* cwd load on demand when Claude reads
files there (and are *not* re-injected after `/compact` until then; the project-root `CLAUDE.md`
is). Use `claudeMdExcludes` (glob list, in `.claude/settings.local.json` or any settings layer) to
skip ancestor files in a monorepo; managed `CLAUDE.md` cannot be excluded.

## Configure

Plain Markdown — any headings, no schema. Block-level HTML comments (`<!-- … -->`) are stripped
before injection (use them for human-only notes). `@path` imports expand into context at launch:
relative paths resolve against the importing file; recursive imports allowed, **max depth 5 hops**;
the first external import triggers a one-time approval dialog. (Imports load at launch too — they
organize, they don't shrink context; for that use [`.claude/rules/`](rules.md) path-scoping.)

| Invoke | What it does |
|--------|--------------|
| `/init` **[built-in]** | Scans the codebase and generates a starter `CLAUDE.md` (set `CLAUDE_CODE_NEW_INIT=1` for the interactive multi-phase flow; reads an existing `AGENTS.md` / `.cursorrules` / `.windsurfrules` to seed it; suggests improvements rather than overwriting an existing file). |
| `/memory` **[built-in]** | Lists the `CLAUDE.md` / `CLAUDE.local.md` / rules files loaded this session and opens any for editing; toggles auto memory; opens the auto-memory folder. |
| `#<text>` (prompt prefix) **[built-in]** | "Remember this" → saved to **auto memory** (`~/.claude/projects/<project>/memory/`), not `CLAUDE.md`. To add to `CLAUDE.md`, ask Claude "add this to CLAUDE.md" or edit via `/memory`. |
| `/claude-md-management:revise-claude-md` **[plugin]** | Updates `CLAUDE.md` with learnings from the current session. |
| `/claude-md-management:claude-md-improver` **[plugin]** | Scans `CLAUDE.md`/`AGENTS.md` against quality templates and applies targeted fixes. |
| `--append-system-prompt "<text>"` (CLI) | For instructions you want at the *system-prompt* level — must be passed every invocation; better for scripts than interactive use. |

### Importing `AGENTS.md`

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. To use the open-standard file:

```markdown
@AGENTS.md

## Claude Code
Claude-specific instructions can go here, below the import.
```

…or `ln -s AGENTS.md CLAUDE.md` if you don't need Claude-specific additions (on Windows a symlink
needs Administrator / Developer Mode — use the `@AGENTS.md` import there). See
[`reference/agents-md.md`](../reference/agents-md.md).

### Auto memory

Claude writes its own notes across sessions under `~/.claude/projects/<project>/memory/` — a
`MEMORY.md` index plus topic files. Only the first **200 lines / 25 KB** of `MEMORY.md` is loaded
each session; topic files load on demand. On by default (requires v2.1.59+); toggle via `/memory`,
`autoMemoryEnabled` in settings, or `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`. Relocate with
`autoMemoryDirectory` (user/policy settings only). Files are plain Markdown — edit or delete freely.

## Validate

| Invoke | What it does |
|--------|--------------|
| `/memory` **[built-in]** | Confirms which `CLAUDE.md` / `CLAUDE.local.md` / rules files are actually loaded — if a file isn't listed, Claude can't see it. |
| `InstructionsLoaded` hook **[built-in]** | Logs exactly which instruction files load, when, and why — useful for debugging path-scoped or lazy-loaded files. |
| `/doctor` **[built-in]** | General config health check (also flags the skill-listing budget). |
| `/claude-md-management:claude-md-improver` **[plugin]** | Scores `CLAUDE.md`/`AGENTS.md` against best-practice templates and reports issues. |
| `harness-optimizer` agent **[plugin]** | Covers `CLAUDE.md` as part of a whole-harness audit. |

If Claude isn't following `CLAUDE.md`: check `/memory` lists it; make instructions more specific
("Use 2-space indentation" beats "format code properly"); look for conflicting instructions across
files; if it must run at a fixed point, use a [hook](hooks.md) instead.

## Improve

**Must**
- No secrets, tokens, or internal URLs — it's committed. Point at `.env.example` or a vault.
- Only enforceable, concrete instructions — Claude follows it literally; aspirational rules are noise. For something that *must* run at a fixed point, use a hook, not a CLAUDE.md line.
- Keep nested files non-contradictory — files are concatenated (closer read last), not "closest wins", so don't restate, only differ.

**Should**
- Keep it **under ~200 lines**. Longer files consume more context and reduce adherence.
- Use Markdown headers and bullets; put exact commands in backticks.
- Move bulky / shared content into [`.claude/rules/`](rules.md) (path-scoped where possible) or `@path` imports.
- Import `AGENTS.md` rather than maintaining two files.
- Update it in the same PR as the workflow change it describes; periodically remove outdated/conflicting lines (and prune `claudeMdExcludes` in monorepos).
- Don't restate the README — link to it.

| Limit | Value | Note |
|-------|-------|------|
| `CLAUDE.md` length | target < ~200 lines | longer → `.claude/rules/` or `@path` imports |
| `@path` import depth | max 5 hops | relative paths resolve against the importing file |
| `MEMORY.md` (auto memory) loaded at start | first 200 lines / 25 KB | topic files load on demand |
| HTML comments | stripped before injection | zero token cost; for human notes |

## Sources

- Memory (CLAUDE.md, load order, imports, auto memory, `AGENTS.md`) — <https://code.claude.com/docs/en/memory>
- Best practices (write an effective CLAUDE.md) — <https://code.claude.com/docs/en/best-practices>
- Extend Claude Code (CLAUDE.md vs Skills vs Rules; context cost) — <https://code.claude.com/docs/en/features-overview>
- Commands (`/init`, `/memory`) — <https://code.claude.com/docs/en/commands> · Hooks (`InstructionsLoaded`) — <https://code.claude.com/docs/en/hooks>
