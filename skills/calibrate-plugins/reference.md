# Plugins calibration reference

> Source of truth: [`docs/features/plugins.md`](../../docs/features/plugins.md).

## Must (for any plugin you write)

- Component directories at the *plugin root* (`skills/`, `agents/`, `hooks/`, `.mcp.json`,
  `.lsp.json`, `monitors/`, `bin/`) — **NOT inside `.claude-plugin/`** (only the manifest goes there).
- A `version` in `.claude-plugin/plugin.json` if you want users to update predictably (without it,
  every commit counts as a new version on git distribution).
- Plugin-shipped subagents ignore `hooks` / `mcpServers` / `permissionMode` — don't include them.

## Should

- Review what a plugin ships before enabling — you import all of its skills, subagents, hooks, MCP,
  LSP at once.
- Install only what you actively use; **disable, don't uninstall** for "maybe later"; prune the
  enabled set periodically.
- Keep plugins updated (`/reload-plugins` after local edits; bump manifest `version` when distributing).
- Prefer `skills/` over the legacy flat `commands/`.
- Plugin-shipped skills should be `disable-model-invocation: true` when they're side-effecting *or*
  when they're a calibration toolkit you don't want carrying standing context cost.

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `plugin:missing-version` | `.claude-plugin/plugin.json` lacks `version` | LOW |
| `plugin:missing-name` | manifest lacks `name` | HIGH |
| `plugin:misplaced-components` | `skills/` / `agents/` / `hooks/` etc. found *inside* `.claude-plugin/` instead of plugin root | HIGH |
| `plugin:legacy-commands-only` | plugin has `commands/` but no `skills/` | LOW |
| `plugin:enabled-not-used-heuristic` | enabled in `installed_plugins.json` but not referenced in recent transcripts (best-effort) | LOW |
| `plugin:duplicate-marketplaces` | the same marketplace registered twice | LOW |
| `plugin:invalid-manifest-json` | manifest doesn't parse | HIGH |
