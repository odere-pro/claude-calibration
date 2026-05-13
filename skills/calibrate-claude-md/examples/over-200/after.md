# Acme App

## What this is

Next.js 15 (app router), Node 20, pnpm 9, deployed to Vercel. Monorepo via Turborepo:

- `apps/web/` — marketing site
- `apps/dashboard/` — authenticated dashboard
- `packages/ui/` — shared UI kit
- `packages/db/` — Drizzle schemas

## Conventions

- React 19 server components by default; `"use client"` only where needed.
- TanStack Query for async client state.
- Zod at every API boundary; never read `process.env` directly (use `lib/env.ts`).
- Drizzle generate + migrate (never `push`) against any non-local env.

## @-imports

@AGENTS.md
@.claude/rules/conventions.md

## House rules

Topic rules in [`.claude/rules/`](.claude/rules/) (path-scoped, load on demand):

- [`frontend.md`](.claude/rules/frontend.md) — Tailwind, shadcn, Framer Motion, design tokens
- [`testing.md`](.claude/rules/testing.md) — Vitest, Playwright, axe, coverage targets
- [`api.md`](.claude/rules/api.md) — API envelope, auth, rate limit
- [`database.md`](.claude/rules/database.md) — Drizzle, migrations, pooling
- [`performance.md`](.claude/rules/performance.md) — CWV targets, bundle budgets
- [`security.md`](.claude/rules/security.md) — CSP, HSTS, CSRF, audit cadence
- [`deployment.md`](.claude/rules/deployment.md) — Vercel envs, Sentry, PostHog

## See also

- [`README.md`](README.md) — public overview (do not restate here)
- [`AGENTS.md`](AGENTS.md) — agent routing

<!--
After-state notes (calibrator output, not part of file):
- CLAUDE.md trimmed from ~250 effective lines to ~50.
- 7 path-scoped rule files created under .claude/rules/ (companion edits in calibrate-rules).
- Vague verbs ("always test", "be careful") replaced with concrete pointers.
- README-restating sections removed; link added.
-->
