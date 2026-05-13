---
name: calibrate-plugins
description: >-
  Audits installed plugins, registered marketplaces, and (when the project itself is a plugin)
  the local manifest at `.claude-plugin/plugin.json`. Flags manifests missing `name` or
  `version`, manifests that don't parse, components misplaced under `.claude-plugin/` instead of
  at the plugin root, plugins that use legacy `commands/` without `skills/`, duplicate
  marketplace registrations, and the "enabled but unused" heuristic. Also handles the
  `kind: create` row when a plugin needs a scaffolded manifest. Invoked by the calibration
  orchestrator (`/calibrate`) and standalone via `/claude-calibration:calibrate-plugins`.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(bash *), Edit(.claude-plugin/*.json), Write(.claude-plugin/*.json)
---

# calibrate-plugins — per-feature bundle

You audit and tune plugin manifests, plugin layouts, marketplace registrations, and the
installed-plugins state file. Two entry points:

- **Direct invocation** (`/claude-calibration:calibrate-plugins`) — audit everything, report
  findings, propose fixes inline.
- **Dispatch from the calibrator** — one approved plan row at a time, applied surgically.

The workflow is the same; only the framing differs.

## 1. Enumerate

```bash
bash <BUNDLE>/scripts/enumerate.sh "$PROJECT_DIR"
```

Yields TSV `scope\tpath`. Scopes:

- `installed` — `~/.claude/plugins/installed_plugins.json`.
- `marketplaces` — `~/.claude/plugins/known_marketplaces.json`.
- `cache` — one row per installed plugin payload under `~/.claude/plugins/cache/`.
- `self-manifest` — when the project is itself a plugin, its `.claude-plugin/plugin.json`.
- `self-component` — sibling component dirs / files at the plugin root.
- `self-misplaced` — components found inside `.claude-plugin/` instead of at the plugin root.

## 2. Lint

```bash
bash <BUNDLE>/scripts/lint.sh <path …>
```

Yields TSV `path\tsignature\tseverity\tdetail`. The signatures this bundle owns
(see `reference.md`):

- `plugin:missing-name` (HIGH)
- `plugin:missing-version` (LOW)
- `plugin:misplaced-components` (HIGH)
- `plugin:legacy-commands-only` (LOW)
- `plugin:enabled-not-used-heuristic` (LOW) — best-effort, transcripts-based
- `plugin:duplicate-marketplaces` (LOW)
- `plugin:invalid-manifest-json` (HIGH)

## 3. Fix — `kind: edit` rows

- `plugin:missing-name` → `examples/missing-name/{before,after}.md` not shipped; the fix is
  trivial — add `"name": "<plugin-name>"` to the manifest. Name should match the directory.
- `plugin:missing-version` → `examples/missing-version/{before,after}.md`. Add `"version":
  "0.1.0"` and bump on each release. On git distribution every commit is implicitly a new
  version; explicit `version` lets users pin and skill registries deduplicate.
- `plugin:misplaced-components` → move the offending directory from `.claude-plugin/<sub>` to
  `<plugin-root>/<sub>`. The manifest lives in `.claude-plugin/`; everything else lives at the
  plugin root.
- `plugin:legacy-commands-only` → migrate the `commands/` entries to `skills/<name>/SKILL.md`.
  Skills load on demand and have richer frontmatter; commands are kept for backwards-compat.
- `plugin:duplicate-marketplaces` → remove the duplicate entry from `known_marketplaces.json`
  via `/plugin` (don't hand-edit the file unless you really mean it).
- `plugin:invalid-manifest-json` → fix the JSON. `python3 -m json.tool <manifest>` locates the
  parse error.
- `plugin:enabled-not-used-heuristic` → confirm with the user, then disable via `/plugin
  disable <name>`. Re-enable on demand.

## 4. Create — `kind: create` rows

When the planner detects a plugin needs scaffolding (rare from this bundle — usually a
companion to a `kind: create` row from another bundle that needs a host plugin):

- Copy `templates/plugin.json.tmpl` to `<plugin-root>/.claude-plugin/plugin.json` and fill in
  `{{name}}`, `{{description}}`, `{{version}}`, `{{author}}`, `{{license}}`, `{{keywords}}`.
- Create the standard component dirs at the plugin root (`skills/`, `agents/`, `hooks/`,
  `rules/` — only the ones you actually need).

## 5. Verify

After every edit or create, re-run `bash <BUNDLE>/scripts/lint.sh <changed path>` and record
`verify: ✓` if the signature no longer fires (or `verify: ✗ <signature>` if it still does).

## Hard rules

- Components live at the **plugin root**, never inside `.claude-plugin/`. The manifest is the
  only thing in `.claude-plugin/`.
- Every manifest must have `name`; `version` is strongly recommended (LOW today, but every
  commit is a new version on git distribution — explicit is better).
- Plugin-shipped rules need `paths:` frontmatter (enforced by `calibrate-rules`, not here, but
  worth noting cross-bundle).
- Don't hand-edit `installed_plugins.json` or `known_marketplaces.json` — use `/plugin`.
