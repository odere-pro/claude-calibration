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
