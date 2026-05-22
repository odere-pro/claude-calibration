---
name: docs-update
description: >-
  Author-only maintenance skill for the claude-calibration repo. Refreshes the docs/ rubric against
  the official Claude Code docs: fans out to the docs-fetcher agent (one page at a time), diffs the
  live facts against each local page, and updates docs/ in place — preserving the page template
  (Definition → Scope → Configure → Validate → Improve → Sources) and the `## Sources` block. Proposes
  edits and waits for approval. Invoke explicitly as /docs-update [page-or-feature].
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Edit(docs/**), Write(docs/**), Agent
---

# docs-update

Bring the `docs/` rubric back in line with the upstream Claude Code docs. Pairs with `/docs-status`
(which tells you what looks stale) and feeds `/plugin-update` (which realigns the bundles afterward).

## Scope

With no argument, process every page that has a `## Sources` block. With an argument
(`/docs-update skills` or `/docs-update docs/features/hooks.md`), process just that page.

## Steps

1. **Enumerate** target pages and read each one's `## Sources` URLs.
2. **Fetch, one page at a time.** For each source URL, spawn the `docs-fetcher` agent with that URL
   (and the local page path for context). Do **not** fetch in parallel — one page per call keeps each
   fetch bounded and the diff focused. If a fetch returns `ERROR:`, skip that page and report it.
3. **Diff the facts.** Compare the live normative facts (limits, required fields, file paths, command
   names, exit-code semantics, version notes) against the local page. Only real drift matters — ignore
   prose wording differences.
4. **Propose edits.** Present a per-page summary of what changed upstream and the exact edits you'd
   make. Wait for approval before writing (this skill is `disable-model-invocation: true`; the user
   ran it deliberately, but still confirm before editing).
5. **Apply**, preserving:
   - the shared page template (Definition → Scope → Configure → Validate → Improve → Sources);
   - the `## Sources` block (update URLs only if the upstream page moved);
   - the repo's own vocabulary (`docs/glossary.md`) and signature names (`rules/signatures.md`).
6. **Hand off.** When facts that the per-feature bundles encode (limits, required fields) changed,
   tell the user to run `/plugin-update` next so `reference.md` / `templates/` / `scripts/lint.sh`
   catch up.

## Boundaries

- Writes only under `docs/` (`allowed-tools` scopes `Edit`/`Write` to `docs/**`).
- Never invents facts a fetch didn't return; an unreachable source leaves its page unchanged.
- Never renames a pattern signature or a glossary term as a side effect.
