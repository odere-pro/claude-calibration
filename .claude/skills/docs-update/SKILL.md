---
name: docs-update
description: >-
  Refresh this repo's docs/ set against the official Claude Code docs. For each page, fetches its
  Sources URLs (via the docs-fetcher subagent, one page at a time, so the HTML stays out of the main
  window), diffs the facts, and updates the doc in place — preserving the template structure, the DRY
  rule, and the Sources sections. Side-effecting; only you can run it (/docs-update). Pass a page name
  to limit scope.
argument-hint: "[page name, optional]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent, TodoWrite
---

# docs-update — bring docs/ in step with the official docs

You update `docs/*.md` so its facts match the current official Claude Code documentation. You do **not**
touch the plugin's `skills/` or `agents/` — that's `/plugin-update`. Work **one page at a time**.

## Do

1. Decide the set: if `$ARGUMENTS` names a page, just that one; otherwise every `docs/*.md` and
   `docs/**/*.md` (consider doing the most-stale-first; `/docs-status` can tell you).
2. For each page:
   a. Read it. Pull the URLs from its `## Sources` section.
   b. For **each** Sources URL: `Agent(docs-fetcher)` with `URL: <url>` and `Repo doc: <this page's path>`.
      Collect each subagent's structured comparison (NEW/CHANGED, REMOVED, SOURCE-URL DRIFT, NOTES).
   c. If the upstream and the page already agree on everything checked, leave the page alone — say so.
      Otherwise edit the page **surgically**:
      - Correct claims that drifted; add facts that are genuinely new; remove claims for features that
        were removed.
      - **Preserve the template**: `# <Feature>` → one-line def → `## Definition` / `## Scope` /
        `## Configure` / `## Validate` / `## Improve` (Must / Should / a limits table) / `## Sources`.
        `README.md` / `glossary.md` / `reference/*.md` keep their own shapes.
      - **Honour DRY**: a fact lives on one page; if a fact belongs elsewhere (scope/precedence/load
        order live in `general-setup.md` or the owning feature page), link to it — don't restate it.
      - Keep the prose terse and in the doc-set's voice (declarative, concrete, "what it does / how to
        configure / how to validate / how to improve").
      - Update the `## Sources` URLs if `SOURCE-URL DRIFT` reported a move.
   d. Reflect changes in `docs/README.md`'s index/feature tables if a page was added/removed/renamed.
3. After all pages: summarize — which pages changed, the headline change in each, and any change that
   has knock-on effects for the plugin's own components (a new frontmatter key, a renamed command, a
   changed limit). End with: `Next: /plugin-update to bring the plugin in line; bump plugin.json
   "version" if the plugin changes.`

## Don't

- Don't fetch more than one page's worth at a time into the main window — delegate to `docs-fetcher`.
- Don't invent facts the fetched pages don't support; if something is unclear, note it rather than
  guessing.
- Don't reformat pages wholesale or change their structure to "improve" them — match the existing
  template.
- Don't touch `skills/`, `agents/`, or `.claude-plugin/plugin.json` here.
