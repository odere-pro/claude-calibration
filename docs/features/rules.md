[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# `.claude/rules/`

Modular instruction files — one topic per file — that load like `.claude/CLAUDE.md`, optionally
scoped to file paths so they only enter context when relevant.

## Definition

`.claude/rules/*.md` keeps instructions modular: each file covers one topic (`testing.md`,
`api-design.md`, …), discovered recursively (so you can use subdirectories like `frontend/`). A
rule with `paths:` frontmatter loads only when Claude works with matching files — that's the point:
it's how you keep [`CLAUDE.md`](claude-md.md) small without losing the instructions. Rules without
`paths:` load unconditionally, at the same priority as `.claude/CLAUDE.md`. The directory supports
symlinks (resolved normally; circular symlinks handled). **Context cost:** unconditional rules —
every request; path-scoped rules — only when matching files are opened. Both `CLAUDE.md` and
`rules/` are *instruction files*; see [`claude-md.md`](claude-md.md) for the umbrella.

## Scope

[Additive](../glossary.md), like `CLAUDE.md`.

| Scope | Location | Loads |
|-------|----------|-------|
| user | `~/.claude/rules/*.md` | before project rules (project rules get higher priority on conflict) |
| project | `.claude/rules/*.md` (recursively) | at the priority of `.claude/CLAUDE.md` |
| `--add-dir` | `.claude/rules/*.md` in an added directory | only with `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` |

## Configure

A rule file is plain Markdown with optional YAML frontmatter:

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "src/**/*.{ts,tsx}"
---

# API Development Rules
- All API endpoints must include input validation
- Use the standard error response format
```

`paths` accepts glob patterns (a comma-separated string or a YAML list); brace expansion works
(`src/**/*.{ts,tsx}`). Path-scoped rules trigger when Claude *reads* a matching file, not on every
tool use. Rules with no `paths` apply to all files.

| Invoke | What it does |
|--------|--------------|
| *(add a file)* | Drop `*.md` files in `.claude/rules/` (or `~/.claude/rules/`); no built-in generator. |
| `/init` **[built-in]** | The interactive flow (`CLAUDE_CODE_NEW_INIT=1`) can scaffold rules alongside `CLAUDE.md`. |
| `/memory` **[built-in]** | Lists rules files loaded this session and opens any for editing. |
| symlink | `ln -s ~/shared-rules .claude/rules/shared` (a directory) or `ln -s ~/standards/security.md .claude/rules/security.md` (a file) to share a rule set across projects. |

## Validate

| Invoke | What it does |
|--------|--------------|
| `/memory` **[built-in]** | Confirms which rules files are loaded this session — if a file isn't listed, it isn't being applied. |
| `InstructionsLoaded` hook **[built-in]** | Logs exactly which instruction files (including rules) load, when, and why — the way to debug a `paths`-scoped rule that isn't firing. |
| `/doctor` **[built-in]** | General config health check. |

## Improve

**Must**
- No secrets — committed and additive into context. Point at `.env.example` or a vault.
- Keep rules non-contradictory with each other and with `CLAUDE.md` (concatenated; closer read last).

**Should**
- One topic per file; descriptive filenames (`testing.md`, `security.md`).
- Use `paths:` for anything language- or directory-specific — it loads only when relevant, which is the whole reason `.claude/rules/` exists.
- Move bulky sections of `CLAUDE.md` here rather than letting `CLAUDE.md` grow past ~200 lines.
- Reach for a [skill](skills.md) instead when the content is a *workflow* (multi-step task) rather than always-applicable guidance — skills load on demand only.

| Limit | Value | Note |
|-------|-------|------|
| Unconditional rule | always in context | use sparingly; prefer `paths:`-scoped |
| Path-scoped rule | in context only when a matching file is opened | the cheap option |
| Discovery | recursive under `.claude/rules/` | subdirectories OK; symlinks OK |

## Sources

- Memory → "Organize rules with `.claude/rules/`" / path-specific rules — <https://code.claude.com/docs/en/memory>
- Extend Claude Code (CLAUDE.md vs Rules vs Skills) — <https://code.claude.com/docs/en/features-overview>
- Hooks (`InstructionsLoaded`) — <https://code.claude.com/docs/en/hooks> · Commands (`/init`, `/memory`) — <https://code.claude.com/docs/en/commands>
