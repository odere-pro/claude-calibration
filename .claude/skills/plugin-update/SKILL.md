---
name: plugin-update
description: >-
  Author-only maintenance skill for the claude-calibration repo. Realigns the plugin's own components
  with the now-current docs/ rubric: walks each skills/calibrate-*/reference.md, its templates/, and
  scripts/lint.sh constants, and updates any limits / required fields / signatures that drifted from
  the matching docs/features/*.md. Proposes a plugin.json version bump and waits for approval. Run
  after /docs-update. Invoke explicitly as /plugin-update [feature].
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Edit(skills/calibrate-*/**), Edit(.claude-plugin/plugin.json), Bash(bash skills/calibrate-*/scripts/*.sh:*)
---

# plugin-update

After `/docs-update` refreshes `docs/`, this skill propagates any changed facts into the per-feature
bundles so the rubric the plugin *grades against* and the rubric it *ships* stay identical.

## Scope

With no argument, process all nine `calibrate-<feature>` bundles. With an argument
(`/plugin-update skills`), process just that feature.

## Steps

1. **Pair** each bundle with its source: `skills/calibrate-<feature>/reference.md` ↔
   `docs/features/<feature>.md` (each `reference.md` already cites its source-of-truth page).
2. **Diff the encoded facts** between the docs page and the bundle's `reference.md`, `templates/*`,
   and the constants in `scripts/lint.sh` (e.g. `NAME_MAX`, `DESC_MAX`, `BODY_MAX`, threshold values
   embedded in signatures like `over-200`).
3. **Respect the signature contract.** If a limit moved (e.g. body cap 500 → 600), the signature name
   carrying the threshold (`skill:body-over-500`) changes too — and that means the **four-places**
   update from [`../../rules/CLAUDE.md`](../../rules/CLAUDE.md): `rules/signatures.md`, the bundle's
   `reference.md`, its `scripts/lint.sh` emit, and `rules/dispatch.md`. Never rename a signature
   silently — call it out.
4. **Propose edits**, grouped by bundle, and wait for approval before writing.
5. **Verify** after each bundle: re-run its `scripts/lint.sh` on its own templates/examples to confirm
   it still emits cleanly.
6. **Propose a version bump.** Summarise what changed and recommend a `plugin.json` `version` bump
   (patch for limit tweaks, minor for a new signature/check). Leave the actual bump + changelog
   fragment to the user — this skill does not edit `plugin.json` or tag a release.

## Boundaries

- Edits bundle files under `skills/calibrate-*/` and `rules/` only; never `plugin.json`, never a tag.
- The plugin-dev write-guard (`.claude/hooks/plugin-dev-guard.sh`) still applies: a `rules/` file must
  keep its `paths:` frontmatter.
