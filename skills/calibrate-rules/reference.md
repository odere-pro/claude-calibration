# Rules calibration reference

> Source of truth: [`docs/features/rules.md`](../../docs/features/rules.md).

## Must

- No secrets — rules are committed and load additively into context.
- Non-contradictory with `CLAUDE.md` and with each other (concatenated; closer read last).

## Should

- One topic per file; descriptive filename (`testing.md`, not `misc.md`); group related rules in
  subdirectories.
- **`paths:` for anything language- or directory-specific** — it then loads only when Claude touches
  matching files. Keep unconditional (`paths`-less) rules to the always-relevant minimum.
- Each file short and focused (~screen, well under ~200 lines); `# Title` → bullets; concrete and
  verifiable.
- Move bulky sections out of `CLAUDE.md` into here rather than letting `CLAUDE.md` grow past ~200.
- Reach for a [skill](../calibrate-skills/) when the content is a multi-step workflow rather than
  always-applicable guidance.
- Symlinks for sharing canonical rule sets across repos.

## Limits

| Aspect | Recommended |
|---|---|
| Per rule file | < ~200 lines |
| Unconditional rules | minimum (use `paths:` when feasible) |
| Glob format | comma-separated string OR YAML list; brace expansion supported |

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `rule:secret-leak` | Same patterns as `claude-md:secret-leak` | **CRITICAL** |
| `rule:over-200` | Effective lines > 200 | MEDIUM |
| `rule:no-paths-when-language-specific` | Filename / content suggests a specific language or directory (`testing-typescript.md`, body cites `*.ts` patterns) but no `paths:` frontmatter | MEDIUM |
| `rule:plugin-shipped-no-paths` | Rule lives under a plugin's `rules/` (i.e. there's a `.claude-plugin/plugin.json` in the same plugin root) but has no `paths:` frontmatter — it would load always-on for every user who enables the plugin | HIGH |
| `rule:bad-glob` | `paths:` frontmatter doesn't parse as a YAML list of strings, or contains an obviously broken glob | HIGH |
| `rule:contradicts-claude-md` | A rule restates a topic CLAUDE.md already covers (overlap heuristic) | LOW |
| `rule:should-be-skill` | Rule body describes a multi-step workflow (numbered steps, "Run X then Y then Z") rather than always-on guidance | LOW |
