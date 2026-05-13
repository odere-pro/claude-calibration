# Bloated CLAUDE.md (BEFORE — 412 lines)

```markdown
# my-app

A Next.js + tRPC + Prisma app for Acme Corp.

## Build & test
... (good content, ~30 lines) ...

## API conventions       <-- 90 lines: status codes, error envelope, pagination, …
## Testing               <-- 80 lines: unit / integration / E2E patterns, mocking conventions, …
## Security              <-- 60 lines: CSP, auth, rate limits, OWASP-class avoidance, …
## Accessibility         <-- 40 lines: WCAG, keyboard nav, reduced motion, …
## Frontend patterns     <-- 50 lines: components, hooks, state management, …
## Database              <-- 30 lines: Prisma migrations, query patterns, …
## "always do"           <-- 30 lines, mostly aspirational ("test your changes", "format code") …
```

## Why this is a problem

- **412 lines** loaded in full every request — a measurable adherence drop. The user-facing rule
  "Run `npm test` before committing" gets weighted the same as "Be careful with database migrations,"
  and the model spends attention budget on text it should ignore.
- Topic content (API, testing, security, a11y, frontend, database) **applies only when working on
  that area** — but here it's loaded for every chat, every file, every session.
- "Always do: test your changes" is **aspirational** — Claude can't measure it; the line is pure
  noise.

Pattern signatures: `claude-md:over-400` (HIGH), `claude-md:vague-rules`.
