# Rules

Topic / path-scoped instruction files under `.claude/rules/`. Loaded **on demand** when Claude
touches a matching path — cheap when scoped, expensive when not.

## Definition

- **Files** — `.claude/rules/**/*.md`, plus `~/.claude/rules/**` at user scope.
- **Frontmatter** — `name`, `description`, `paths:` (list of globs). Without `paths:` the rule
  loads on every request.
- **What it does** — adds focused guidance for a topic or directory without bloating CLAUDE.md.

## Scope

User · Project · Plugin-shipped. Plugin-shipped rules without `paths:` load for every user who
enables the plugin — high context cost.

## Configure

- Frontmatter with `paths:` as a YAML list of glob strings (brace expansion supported).
- Markdown body, typically under ~200 lines.
- One topic per file; descriptive filename (`testing-typescript.md`, not `misc.md`).

## Validate

- `bash skills/calibrate-rules/scripts/lint.sh <rule.md>` — emits `rule:over-200`,
  `:no-paths-when-language-specific`, `:plugin-shipped-no-paths`, `:bad-glob`,
  `:contradicts-claude-md`, `:should-be-skill`, `:secret-leak`.

## Improve

| Must         | Should                                                                  | Limit         |
| ------------ | ----------------------------------------------------------------------- | ------------- |
| No secrets   | Add `paths:` for any language/dir-specific rule                         | < 200 lines   |
| No conflicts | Move multi-step workflows into a skill instead of an always-on rule     |               |
| with CLAUDE.md | Symlink for sharing canonical sets across repos                       |               |

## Sources

- Memory — <https://code.claude.com/docs/en/memory>
- Settings — <https://code.claude.com/docs/en/settings>
