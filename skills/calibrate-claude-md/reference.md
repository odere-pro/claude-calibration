# CLAUDE.md calibration reference

> Source of truth: [`docs/features/claude-md.md`](../../docs/features/claude-md.md).

## Must

- No secrets in committed `CLAUDE.md` — committed files load into every session.
- Files referenced via `@`-imports must exist and not chain more than ~5 hops deep.
- Don't contradict nested `**/CLAUDE.md` files (closer file wins; surprises hide here).

## Should

- Keep each `CLAUDE.md` short (< ~200 effective lines); move bulky topic blocks into
  `.claude/rules/<topic>.md` with `paths:` scoping.
- Concrete rules with verifiable wording, not aspirational verbs ("test your changes", "be
  careful", "always") — those are hook material or path-scoped rules.
- Import `AGENTS.md` (`@AGENTS.md`) when a sibling agent file exists, so its routing context loads
  alongside `CLAUDE.md`.
- Link to `README.md` rather than restating it.
- One topic per nested `CLAUDE.md`; never have ≥ 3 nested `CLAUDE.md` files describing the same
  surface.

## Limits

| Aspect | Recommended |
|---|---|
| Per `CLAUDE.md` file | < ~200 effective lines (HIGH at > 400) |
| `@`-import chain depth | ≤ 5 hops |
| Aspirational verbs without an enforcement hook | 0 |

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `claude-md:secret-leak` | Any `*KEY`/`*TOKEN`/`*PASSWORD`/`*SECRET`/`sk-...`/`api_key=...` pattern in `CLAUDE.md` or `CLAUDE.local.md` | **CRITICAL** |
| `claude-md:over-200` | File > 200 effective lines | MEDIUM |
| `claude-md:over-400` | File > 400 effective lines | HIGH |
| `claude-md:vague-rules` | Aspirational verbs without specifics ("test your changes", "format code", "be careful") | MEDIUM |
| `claude-md:no-agents-md-import` | `AGENTS.md` exists in the same dir but no `@AGENTS.md` reference in `CLAUDE.md` | LOW |
| `claude-md:imports-too-deep` | `@`-import chain > 5 hops | HIGH |
| `claude-md:contradicts-nested` | Two CLAUDE.md files at different levels state contradictory rules on the same topic | MEDIUM |
| `claude-md:must-rule-with-no-hook` | Body says "always do X" / "never do Y" / "must Z" — should be a hook, not a request | MEDIUM |
| `claude-md:restated-readme` | Body restates README content rather than linking to it | LOW |
