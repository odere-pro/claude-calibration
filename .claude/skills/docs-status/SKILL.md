---
name: docs-status
description: >-
  Read-only status report on this repo's docs/ set: per page, its Sources URLs, the last commit that
  touched it, and a template-structure check (Definition / Scope / Configure / Validate / Improve /
  Sources). Flags pages that look stale and recommends /docs-update. Use to see whether the doc-set
  needs a refresh against the official Claude Code docs.
argument-hint: "[page name, optional]"
---

# docs-status — is the doc-set in good shape?

Read-only. Inspect `docs/` (or just the page named in `$ARGUMENTS`, if given) and report.

## Do

1. Enumerate `docs/*.md` and `docs/**/*.md`. (`docs/README.md`, `docs/glossary.md`,
   `docs/general-setup.md`, `docs/features/*.md`, `docs/reference/*.md`.)
2. For each page, gather:
   - **Last touched:** `git log -1 --format='%h %cs %s' -- <path>`.
   - **Sources:** the URLs listed under its `## Sources` section (Grep for `https://`).
   - **Template check** (feature pages and `general-setup.md`): does it have the sections
     `## Definition`, `## Scope`, `## Configure`, `## Validate`, `## Improve`, `## Sources`? Note any
     missing or out-of-order. (`README.md`, `glossary.md`, `reference/*.md` use their own shapes — just
     confirm they have a `## Sources` section where the doc-set convention expects one.)
   - **Length:** `wc -l` — flag anything unusually long for its kind.
3. Heuristic **staleness** flag per page: last-touched older than ~3 months, OR a template section
   missing, OR a `## Sources` URL that 404s if you happen to know it does — otherwise "looks current
   (verify with /docs-update)".

## Output (to the user, concise)

A table: `page · last touched · # sources · template OK? · status`. Then a short verdict: which pages
(if any) look stale or malformed, and the recommendation — run `/docs-update` (optionally
`/docs-update <page>`) to check against upstream and refresh, then `/plugin-update` to bring the
plugin's own components in line.

Make no changes. This skill only reports.
