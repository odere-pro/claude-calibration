# CLAUDE.md

The repo's and user's standing instruction file(s) — concatenated into every session as part of
the always-on context.

## Definition

- **Files** — `CLAUDE.md` and `CLAUDE.local.md` at the project root; `~/.claude/CLAUDE.md` at user
  scope; nested `**/CLAUDE.md` in monorepos. The user file `~/.claude/CLAUDE.md` is loaded for
  every session; project files load when `cwd` is at or below their parent.
- **What it does** — declares standing instructions, conventions, project facts, and `@`-imports
  (`@AGENTS.md`, `@.claude/rules/<file>.md`).
- **Context cost** — always-on. Every line costs tokens on every turn. Keep it lean.

## Scope

User · Project · Nested. Concatenated additively (closer files read last → override).
`CLAUDE.local.md` is git-ignored; `CLAUDE.md` is committed.

## Configure

- Markdown body + optional YAML frontmatter (rarely used for CLAUDE.md itself).
- Use `@<path>` to import another file relative to the CLAUDE.md location.
- Keep under ~200 effective lines per file. Move bulky topic-specific content into
  `.claude/rules/<topic>.md` with `paths:` scoping.
- Never commit secrets, API keys, tokens.

## Validate

- `/doctor` flags context-budget overflow.
- `/context all` shows the actual token breakdown.
- `bash skills/calibrate-claude-md/scripts/lint.sh CLAUDE.md` (this plugin) emits pattern
  signatures: `claude-md:secret-leak`, `:over-200`, `:over-400`, `:vague-rules`,
  `:no-agents-md-import`, `:imports-too-deep`, `:contradicts-nested`,
  `:must-rule-with-no-hook`, `:restated-readme`.

## Improve

| Must                                | Should                                                 | Limit            |
| ----------------------------------- | ------------------------------------------------------ | ---------------- |
| No secrets                          | One topic per section; link out for the rest           | < 200 lines      |
| Import-chain depth ≤ 5              | Move language/area-specific blocks to path-scoped rule | < 5 import hops  |
| No contradictions with nested files | Replace aspirational verbs with verifiable specifics   |                  |

When a "must"/"always"/"never" line appears, prefer a `PreToolUse` hook that enforces it over a
prose request — see [`hooks.md`](hooks.md).

## Sources

- Memory — <https://code.claude.com/docs/en/memory>
- AGENTS.md open standard — <https://agents.md>
