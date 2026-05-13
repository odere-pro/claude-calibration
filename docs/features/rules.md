[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# `.claude/rules/`

Modular instruction files — one topic per file — that load like `.claude/CLAUDE.md`, optionally
scoped to file paths so they only enter context when they're relevant.

## Definition

`.claude/rules/*.md` keeps instructions modular: each file covers one topic (`testing.md`,
`api-design.md`, `security.md`, …), discovered recursively so you can group them in subdirectories
(`frontend/`, `backend/`). A rule with a `paths:` frontmatter field loads only when Claude works
with files matching its globs — that's the whole point: it's how you keep [`CLAUDE.md`](claude-md.md)
short without losing the instructions. A rule with _no_ `paths:` loads unconditionally, at the same
priority as `.claude/CLAUDE.md`. The directory supports symlinks (resolved normally; circular
symlinks are detected and handled). **Context cost:** unconditional rules — full content, every
request (like `CLAUDE.md`); path-scoped rules — nothing until a matching file is opened. Both
`CLAUDE.md` and `rules/` are _instruction files_; see [`claude-md.md`](claude-md.md) for the
umbrella, the load order, and `@path` imports.

## Scope

[Additive](../glossary.md), like `CLAUDE.md` — all in-scope rule files contribute; nothing is
suppressed.

| Scope       | Location                                   | Loads                                                                             |
| ----------- | ------------------------------------------ | --------------------------------------------------------------------------------- |
| user        | `~/.claude/rules/*.md` (recursively)       | before project rules — so project rules win on a conflict                         |
| project     | `.claude/rules/*.md` (recursively)         | at the priority of `.claude/CLAUDE.md` (or only on matching files, with `paths:`) |
| `--add-dir` | `.claude/rules/*.md` in an added directory | only with `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`                        |

## Configure

A rule file is plain Markdown with optional YAML frontmatter; the only frontmatter key is `paths`:

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "src/**/*.{ts,tsx}"
  - "tests/**/*.test.ts"
---

# API Development Rules

- All API endpoints must include input validation
- Use the standard error response format
- Include OpenAPI documentation comments
```

`paths` accepts glob patterns — a comma-separated string or a YAML list — and brace expansion
(`src/**/*.{ts,tsx}`). A path-scoped rule triggers when Claude _reads_ a matching file, not on every
tool use. A rule with no `paths` applies to all files (it's just a split-out chunk of `CLAUDE.md`).

| Invoke                   | What it does                                                                                                                                                                            |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| _(add a file)_           | Drop `*.md` files into `.claude/rules/` (or `~/.claude/rules/`), one topic each; there's no built-in generator. Add `paths:` frontmatter to anything language- or directory-specific.   |
| `/init` **[built-in]**   | With `CLAUDE_CODE_NEW_INIT=1` the interactive flow can scaffold rules alongside `CLAUDE.md` as part of the proposal it presents.                                                        |
| `/memory` **[built-in]** | Lists every rules file loaded this session and opens any of them for editing — and tells you which path-scoped rules have _not_ loaded yet.                                             |
| symlink                  | `ln -s ~/shared-rules .claude/rules/shared` (a whole directory) or `ln -s ~/standards/security.md .claude/rules/security.md` (one file) to share a maintained rule set across projects. |

## Validate

| Invoke                                   | What it does                                                                                                                                                                                                      |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/memory` **[built-in]**                 | Confirms which rules files are actually loaded this session — if a file isn't listed (and isn't a path-scoped rule whose paths haven't matched yet), it isn't being applied; check the location and any `paths:`. |
| `InstructionsLoaded` hook **[built-in]** | A hook that fires as instruction files load; log it to see exactly which rules loaded, when, and why — the way to debug a `paths:`-scoped rule that isn't firing on the files you expected.                       |
| `/doctor` **[built-in]**                 | General config health check (rules feed the same context budget as `CLAUDE.md`).                                                                                                                                  |
| `harness-optimizer` agent **[plugin]**   | Reviews the rules set as part of a harness audit — flags unconditional rules that should be `paths:`-scoped, and rules that contradict `CLAUDE.md` or each other.                                                 |

## Improve

**Must**

- No secrets — rules are committed and load additively into context. Point at `.env.example` or a vault.
- Keep rules non-contradictory with each other and with `CLAUDE.md` (concatenated; closer read last) — review the whole set periodically.

**Should**

- One topic per file; descriptive filename (`testing.md`, not `misc.md`); group related rules in subdirectories.
- Add `paths:` to anything language- or directory-specific — it then loads _only_ when Claude touches those files, which is the entire reason `.claude/rules/` exists. Keep unconditional (`paths`-less) rules to the genuinely-always-relevant minimum.
- Keep each rule file short and focused — same logic as `CLAUDE.md` (target a screen or two, well under ~200 lines); structure it `# Title` → bullets; be concrete and verifiable.
- Move bulky sections out of `CLAUDE.md` into here rather than letting `CLAUDE.md` grow past ~200 lines.
- Reach for a [skill](skills.md) instead when the content is a _workflow_ (a multi-step task you'd trigger with `/name`) rather than always-applicable guidance — skills load only on demand.
- Use symlinks to share a canonical rule set across repos instead of copy-pasting.

| Aspect               | Recommendation                                         | Why                                                               |
| -------------------- | ------------------------------------------------------ | ----------------------------------------------------------------- |
| Granularity          | one topic per file; subdirectories for groups          | easy to maintain; only the relevant ones can be path-scoped       |
| `paths:` frontmatter | use it for any language/dir-specific rule              | the file then costs zero context except on matching files         |
| Unconditional rules  | keep to a minimum                                      | a `paths`-less rule is in context every request, like `CLAUDE.md` |
| File length          | target a screen or two (well under ~200 lines)         | same context economics as `CLAUDE.md`                             |
| Structure            | `# Title` → bullets; concrete, verifiable              | scannable for the model                                           |
| Reuse                | symlink a shared directory/file                        | one source of truth across projects                               |
| Workflow vs. rule    | a multi-step task → a [skill](skills.md), not a rule   | skills load on demand; rules are always-on (or path-on)           |
| Maintenance          | periodic conflict sweep across `CLAUDE.md` + all rules | concatenated instructions drift                                   |

## Sources

- Memory — "Organize rules with `.claude/rules/`" and path-specific rules — <https://code.claude.com/docs/en/memory>
- Extend Claude Code — CLAUDE.md vs Rules vs Skills; context cost — <https://code.claude.com/docs/en/features-overview>
- Hooks (`InstructionsLoaded`) — <https://code.claude.com/docs/en/hooks> · Commands (`/init`, `/memory`) — <https://code.claude.com/docs/en/commands>
