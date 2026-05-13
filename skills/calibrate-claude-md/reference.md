# CLAUDE.md calibration reference

> Source of truth: [`docs/features/claude-md.md`](../../docs/features/claude-md.md). This file is the
> calibration rubric — kept in sync by `/plugin-update`.

## Must

- **No secrets, tokens, internal URLs, customer data** — CLAUDE.md is committed. Point at
  `.env.example` or a secret manager.
- **Only enforce-able instructions.** Claude follows the file literally; aspirational rules are pure
  noise (and context). For something that must hold every time, use a hook (enforcement), not a
  CLAUDE.md line (request).
- **Nested files non-contradictory.** Discovered files are *concatenated* (closer read last), not
  "closest wins" — so don't restate a rule at multiple levels; only state how a level *differs*.

## Should

- **Under ~200 lines per file.** Loaded in full every request; long files dilute attention and
  measurably reduce adherence. The moment it grows past that, move content out.
- **Move bulky / path-specific content** into `.claude/rules/<topic>.md` with `paths:` frontmatter —
  path-scoped rules cost zero context except on matching files.
- **Front-load the most load-bearing rules.** Markdown `##` headers + bullets to group by topic.
  Concrete, verifiable instructions ("Run `npm test` before committing", not "test your changes").
  Exact commands in backticks so they're run verbatim.
- **Import AGENTS.md** if it exists (`@AGENTS.md` at the top of CLAUDE.md). Make AGENTS.md the real
  file; don't maintain two.
- **HTML comments** (`<!-- … -->`) at block level are stripped before injection — free annotations
  for maintainers.
- **Update in the same PR as the workflow change** it describes; periodic conflict sweeps; prune
  `claudeMdExcludes` in monorepos.
- **CLAUDE.local.md** for per-developer overrides (gitignored), or `@~/...` import (survives across
  worktrees).

## Limits

| Aspect | Recommended | Hard cap |
|---|---|---|
| Per CLAUDE.md file | ≤ ~200 lines | none (but adherence drops past this) |
| `@path` import depth | ≤ 5 hops; relative paths resolve against the importing file | 5 hops |
| `MEMORY.md` (auto memory) loaded at start | first 200 lines / 25 KB | hard |

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `claude-md:secret-leak` | Any `*KEY|*TOKEN|*PASSWORD|*SECRET|sk-[a-zA-Z0-9]+|api[_-]?key\s*=` pattern | **CRITICAL** |
| `claude-md:over-200` | File > 200 lines | MEDIUM |
| `claude-md:over-400` | File > 400 lines | HIGH |
| `claude-md:vague-rules` | Aspirational verbs without specifics ("test your changes", "format code", "be careful with") | MEDIUM |
| `claude-md:no-agents-md-import` | `AGENTS.md` exists in the same dir but no `@AGENTS.md` (or symlink) in CLAUDE.md | LOW |
| `claude-md:imports-too-deep` | `@`-import chain > 5 hops | HIGH |
| `claude-md:contradicts-nested` | Two CLAUDE.md files at different levels state contradictory rules on the same topic | MEDIUM |
| `claude-md:must-rule-with-no-hook` | Body says "always do X" / "never do Y" — should be a hook, not a request (cross-feature; this is the headline interaction-evaluation gap) | MEDIUM |
| `claude-md:restated-readme` | Body restates README content rather than linking to it | LOW |
