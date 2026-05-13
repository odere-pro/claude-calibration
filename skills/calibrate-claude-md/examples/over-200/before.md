# Acme App

Acme is a Next.js 15 (app router) project deployed to Vercel. Node 20, pnpm 9. The marketing site
lives in `apps/web/`; the dashboard lives in `apps/dashboard/`; the shared UI kit lives in
`packages/ui/`.

## Code style

- Use Tailwind utility classes for everything.
- Compound components for tabs, dialogs, accordions.
- React 19 server components by default; mark client components with `"use client"`.
- Prefer `cn()` over conditional template strings.
- Always wrap async data in TanStack Query.
- Use CSS variables for design tokens.
- Always test your changes.
- Be careful with state mutations — prefer immutable patterns.
- Never use `any` — always reach for `unknown` + narrowing.
- Format code before committing.
- No console.log left in commits.

## Testing

- Use Vitest for unit tests.
- Use Playwright for E2E.
- Coverage threshold is 80%.
- Run `pnpm test` before opening a PR.
- Snapshot tests for design-system components.
- Visual regression via Chromatic.
- Accessibility checks via axe-playwright on every E2E run.
- E2E tests live in `apps/<app>/e2e/`.
- Unit tests live next to source as `*.test.ts(x)`.

## API conventions

- All routes under `apps/<app>/app/api/`.
- Use Zod for input validation.
- Return `{ success, data, error }` envelope.
- 4xx for client errors; 5xx for server errors.
- Rate limit via `@upstash/ratelimit`.
- Auth via NextAuth v5.
- Never read secrets from `process.env` directly — always go through `lib/env.ts`.

## Database

- PostgreSQL 16 hosted on Supabase.
- Use Drizzle ORM.
- Schemas live in `packages/db/schema/`.
- Migrations via `drizzle-kit`.
- Never run `drizzle-kit push` against production.
- Always use `drizzle-kit generate` + `drizzle-kit migrate`.
- Connection pooling via Supabase pooler.

## Deployment

- Push to `main` → production deploy.
- Push to any other branch → preview deploy.
- Environment variables managed via Vercel dashboard.
- Secrets rotated quarterly.
- Sentry for error tracking.
- PostHog for analytics.

## Monorepo

- Turborepo with `turbo` v2.
- `pnpm` workspaces.
- Shared TS config in `packages/tsconfig/`.
- Shared ESLint config in `packages/eslint-config/`.
- Run `pnpm turbo build` from root to build everything.

## Frontend

- Tailwind v4 with CSS-first config.
- Lucide icons.
- Radix primitives via shadcn/ui (vendored, not as a dep).
- Storybook for component dev.
- Framer Motion for animation.

## Performance

- LCP < 2.5s.
- INP < 200ms.
- CLS < 0.1.
- Bundle budget: 150KB JS gzipped for marketing, 300KB for dashboard.
- Image optimization via `next/image`.
- Preload hero image and primary font.

## Security

- No secrets in committed code.
- CSP with nonces.
- HSTS preload.
- CSRF via NextAuth's built-in.
- Audit `pnpm audit` weekly.

## Git workflow

- Trunk-based: short-lived branches off `main`.
- Conventional commits.
- Squash merge.
- PR template required.
- 1 approver minimum.

## Dependencies

- Check `pnpm outdated` weekly.
- Use Renovate for automated PRs.
- Lock files committed.

## Misc

- Default timezone: UTC.
- Default locale: en-US.
- Date format: ISO 8601.
- Decimal separator: `.`.
- Currency: USD.

(A real over-200 CLAUDE.md often has another 100+ lines of project trivia. This trimmed example
is ~250 effective lines once you count blank lines — over the 200 threshold.)
