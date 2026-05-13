# Calibrated (AFTER — CLAUDE.md is now 87 lines + 6 path-scoped rules)

```markdown
# my-app

A Next.js + tRPC + Prisma app for Acme Corp.

## Build & test

- Install: `pnpm install`
- Run: `pnpm dev`
- Test: `pnpm test`
- Lint / format: `pnpm lint && pnpm format`

## Layout

- `src/app/` — Next.js routes (file-based)
- `src/server/` — tRPC routers + Prisma client
- `src/lib/` — shared utilities, the response envelope (`response.ts`)
- `prisma/` — schema + migrations
- `tests/{unit,integration,e2e}/` — by suite

## Conventions

- HTTP responses use the standard envelope in `src/lib/response.ts`.
- tRPC routers live in `src/server/<resource>.ts`, one resource per file.
- React components live next to the route they support; shared UI in `src/components/ui/`.

## Always do

- Run `pnpm test` before committing.
- Add a Prisma migration in the same PR as the schema change.

## Never do

- Disable ESLint rules to make a build pass — fix the underlying issue.
- Hand-edit a migration after it's been merged — write a follow-up migration.

@AGENTS.md
```

Then `.claude/rules/`:

| File | `paths:` | Was section in CLAUDE.md |
|---|---|---|
| `api.md` | `src/server/**/*.ts` | API conventions (90 lines → 65, kept the concrete rules, dropped the rationale prose) |
| `testing.md` | `tests/**/*.{ts,tsx}` | Testing patterns (80 → 60) |
| `security.md` | `src/{server,lib}/**/*.ts` | Security / CSP / auth / rate limits (60 → 50) |
| `a11y.md` | `src/{app,components}/**/*.{tsx,jsx}` | Accessibility (40 → 35) |
| `frontend.md` | `src/{app,components}/**/*.{tsx,jsx,css}` | Frontend patterns (50 → 40) |
| `database.md` | `{prisma,src/server}/**/*` | Prisma + queries (30 → 25) |

## What changed

- **CLAUDE.md trimmed 412 → 87 lines** — only the always-relevant rules; concrete commands; Layout
  + Conventions front-loaded; AGENTS.md imported.
- **Bulky topic content moved into `.claude/rules/`** with `paths:` — each rule loads only when
  Claude touches a matching file. Total context cost when working on, say, frontend code: only
  `frontend.md` (~40 lines) loads alongside CLAUDE.md, vs. 412 lines previously.
- **Aspirational rules deleted.** "Test your changes" → replaced with the concrete and verifiable
  "Run `pnpm test` before committing." Anything that genuinely must hold every time → became a hook
  in `.claude/settings.json` (a separate `calibrate-hooks` task; flagged as `claude-md:must-rule-with-no-hook`).
- **AGENTS.md imported** via `@AGENTS.md`.

Verify: `scripts/lint.sh` reports `claude-md:over-200` resolved; `claude-md:vague-rules` resolved;
`claude-md:no-agents-md-import` resolved.
