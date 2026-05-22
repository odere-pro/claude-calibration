---
name: docs-status
description: >-
  Author-only maintenance skill for the claude-calibration repo. Read-only staleness report for the
  docs/ rubric: for every page with a `## Sources` block it lists the official source URLs, the git
  last-touched date, and a staleness flag. Use before /docs-update to see which rubric pages may have
  drifted from the upstream Claude Code docs. Never writes. Invoke explicitly as /docs-status.
disable-model-invocation: true
model: haiku
allowed-tools: Read, Grep, Glob, Bash(git log:*)
---

# docs-status

Report which `docs/` pages may have drifted from their official sources. **Read-only** — never edit.

## Steps

1. Enumerate the rubric pages: every `docs/**/*.md` that contains a `## Sources` heading
   (`grep -rl '^## Sources' docs`).
2. For each page, collect:
   - **Sources** — the `https://code.claude.com/docs/...` / `https://agents.md` URLs under its
     `## Sources` block.
   - **Last touched** — `git log -1 --format=%ad --date=short -- <page>`.
   - **Age** — days since that date relative to today.
3. Flag staleness: mark a page `STALE` if its last-touched date is older than ~90 days, `ok`
   otherwise. (Heuristic — git age is a proxy; only `/docs-update` can confirm against the live docs.)

## Output

A table, newest-first, plus a one-line summary:

```
page                              last touched   age    sources   flag
docs/features/skills.md           2026-05-13     9d     2         ok
docs/features/hooks.md            2026-02-01    110d    1         STALE
...
N pages · M flagged STALE. Run /docs-update to refresh against the live docs.
```

## Notes

- This skill only reads. The next step, `/docs-update`, fetches the live pages (via the
  `docs-fetcher` agent) and proposes edits.
- A page with no `## Sources` block is skipped — it isn't grounded in an external doc.
