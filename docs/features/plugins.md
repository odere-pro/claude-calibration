# Plugins

Self-contained bundles of skills, agents, hooks, rules, MCP servers, and commands installed via
`/plugin` or `claude --plugin-dir`.

## Definition

- **Layout** — repo root with `.claude-plugin/plugin.json` (the manifest) plus standard component
  directories at the root: `skills/`, `agents/`, `rules/`, `hooks/`, `commands/`, `.mcp.json`,
  `.lsp.json`, `monitors/`, `bin/`.
- **Manifest** (`.claude-plugin/plugin.json`) — `name` (required), `description`, `version`,
  `author`, `homepage`, `license`, `keywords`.
- **What it does** — registers its components under a `<plugin-name>:` namespace; the user opts
  in via `/plugin enable`.

## Scope

User-installed (via marketplace or `--plugin-dir`). Plugin-shipped components load for every user
who enables the plugin — context cost matters.

### Targeting which plugins a run audits

A calibration run audits every enabled plugin by default. To focus on a subset, pass a plugin
**allow-list / block-list** — see the [plugin filter](../glossary.md) term:

```text
/calibrate --plugins foo,bar    # only foo and bar
/calibrate --plugins -baz       # everything except baz
/calibrate --plugins global     # only globally-installed plugins
/calibrate --plugins local      # only locally-loaded / project plugins
```

Or persist it in `.claude/calibration/config.json` (`{"plugins":{"mode":"include","names":["foo"],
"scope":"all"}}`). The filter matches plugin names across both global and local installs and applies
to every bundle that reaches into plugin caches — `plugins`, `skills`, `subagents`, `hooks`, `mcp` —
so an excluded plugin is dropped from the **entire** audit, not just this page's checks. Full
walkthrough: [usage.md → Targeting specific plugins](../usage.md#targeting-specific-plugins).

## Configure

- Components at the **plugin root**, not inside `.claude-plugin/`. Manifest only lives in
  `.claude-plugin/`.
- Always set `version` — every commit becomes a "new version" on git distribution.
- Prefer `skills/` over `commands/` for new plugins (commands is the legacy form).
- Plugin-shipped rules MUST have `paths:` frontmatter, or they load always-on for every user.

## Validate

- `/plugin` lists installed/enabled plugins.
- `bash skills/calibrate-plugins/scripts/lint.sh <plugin.json | installed_plugins.json>` —
  `plugin:missing-version`, `:missing-name`, `:misplaced-components`, `:legacy-commands-only`,
  `:enabled-not-used-heuristic`, `:duplicate-marketplaces`, `:invalid-manifest-json`.

## Improve

| Must                                | Should                                            | Limit                |
| ----------------------------------- | ------------------------------------------------- | -------------------- |
| Manifest has `name`                 | Set `version`; bump on releases                   | components at root,  |
| Components NOT inside `.claude-plugin/` | Use `skills/` over `commands/`                | not under            |
| Valid JSON                          | Plugin-shipped rules must scope with `paths:`     | `.claude-plugin/`    |

## Sources

- Plugins — <https://code.claude.com/docs/en/plugins>
