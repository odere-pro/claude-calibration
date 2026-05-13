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
