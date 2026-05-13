# Plugins calibration reference

> Source of truth: [`docs/features/plugins.md`](../../docs/features/plugins.md).

## Must

- Manifest at `.claude-plugin/plugin.json` parses as JSON and includes `name`.
- Components (`skills/`, `agents/`, `hooks/`, `rules/`, `commands/`, `.mcp.json`, `.lsp.json`,
  `monitors/`, `bin/`) live at the plugin **root**, not inside `.claude-plugin/`.
- Plugin-shipped rules under `<plugin-root>/rules/` have `paths:` frontmatter (enforced by
  `calibrate-rules`).

## Should

- Set `version` explicitly — every commit counts as a new version on git distribution; explicit
  versions let users pin.
- Prefer `skills/` over the legacy `commands/` form for new plugins. Skills load on demand with
  richer frontmatter; commands are kept for backwards-compat.
- Include `description`, `author`, `license`, `keywords` for discoverability via marketplace.
- Manage `installed_plugins.json` and `known_marketplaces.json` via `/plugin` rather than
  editing them by hand.
- Audit "enabled but never invoked in recent transcripts" plugins periodically — they cost
  context (their always-on rules and skill descriptions all load).

## Limits

| Aspect | Recommended |
|---|---|
| Manifest location | `.claude-plugin/plugin.json` only |
| Component location | plugin root (never `.claude-plugin/<component>`) |
| Required manifest field | `name` |
| Strongly recommended manifest fields | `version`, `description`, `author`, `license` |
| Marketplace duplicates | zero |

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `plugin:missing-name` | manifest lacks `name` | HIGH |
| `plugin:missing-version` | `.claude-plugin/plugin.json` lacks `version` | LOW |
| `plugin:misplaced-components` | `skills/` / `agents/` / `hooks/` etc. found inside `.claude-plugin/` instead of at the plugin root | HIGH |
| `plugin:legacy-commands-only` | plugin has `commands/` but no `skills/` | LOW |
| `plugin:enabled-not-used-heuristic` | enabled in `installed_plugins.json` but not referenced in recent transcripts (best-effort) | LOW |
| `plugin:duplicate-marketplaces` | the same marketplace registered twice | LOW |
| `plugin:invalid-manifest-json` | manifest doesn't parse | HIGH |

## Plugin-scoped /calibrate

The orchestrator (`skills/calibrate/SKILL.md`) accepts a `plugin:<name>` token in its
arguments. The bundle ships a helper script for this:

`scripts/list-plugins.sh [PROJECT_DIR]` — emits TSV: `name\tmarketplace\tversion\tinstall_path\tdescription`
(one row per installed plugin, plus an extra row with marketplace `(local)` when
`<PROJECT_DIR>/.claude-plugin/plugin.json` exists). The orchestrator's preprocessing block
runs this and inlines the TSV so its Pass A0 parser can resolve `plugin:<name>` without
re-running the script.

**Install-path filter (where the actual scoping happens):**
- The orchestrator passes `Plugin install path: <abs>` to the planner-init spawn (which
  persists `plugin_install_path` in `plan.md` frontmatter) and to every evaluator-baseline /
  evaluator-delta fan-out worker.
- Each `calibration-feature-evaluator` worker **post-filters** its bundle's `enumerate.sh` and
  `lint.sh` TSV output: it keeps only rows whose path is equal to `<install_path>` or starts
  with `<install_path>/`. Zero changes to the 9 per-feature `enumerate.sh` scripts.

**Plugin-dev auto-detection.** When `<PROJECT_DIR>/.claude-plugin/plugin.json` exists, the
preprocessing block sets `PLUGIN_DEV_MODE=yes`. The orchestrator's Pass A0 auto-fills the
plugin scope from that manifest when the user didn't supply an explicit `plugin:` token AND
the residual args (after stripping feature + mode tokens) are empty.

**Intent derivation.** When `plugin_scope` is set, the planner derives success criteria from
the plugin's own `plugin.json` `description` (≤200 chars), plus `<install_path>/README.md`
(first 200 lines) and up to 3 of `<install_path>/docs/*.md`. User-supplied intent overrides
the manifest as `intent_verbatim`; the manifest description stays as audit-scope context
under a `**Plugin manifest intent:**` line.
