# Changelog

All notable changes to `claude-calibration` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The version of record is `.claude-plugin/plugin.json` → `version`. Each release is a git tag
`vX.Y.Z`; marketplace consumers update by re-pulling the tagged commit. See
[`docs/RELEASING.md`](docs/RELEASING.md) for the release procedure.

## [Unreleased]

### Added

- `.claude-plugin/marketplace.json` — single-plugin marketplace manifest so the plugin installs via
  `/plugin marketplace add odere-pro/claude-calibration` + `/plugin install claude-calibration@odere-pro`.
- `LICENSE` (MIT), `CHANGELOG.md`, `SOFTWARE-3-0.md`, `docs/glossary.md`, `docs/RELEASING.md`.
- Governance: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, and `.github/`
  issue + pull-request templates.
- CI: `tests/gates/` validation suite (`run-all.sh` + numbered gates) wired through
  `.github/workflows/ci.yml`; tag-triggered `.github/workflows/release.yml`.
- `docs/self-calibration.md` — how the plugin evaluates a setup end to end (the four flows, the
  6-phase loop, worker agents + models, signatures/dispatch, write-guards) and how to audit the
  plugin against itself.
- `docs/evaluating-agentic-workflows.md` — methodology for evaluating multi-agent / multi-skill
  workflows at the node / edge / flow levels, reusing the severity + intent-flow scales, with a PR
  code-review pipeline as the lead example.

### Fixed

- Restored the dangling `docs/glossary.md` link referenced by `docs/README.md`, `docs/install.md`,
  and `docs/usage.md`.
- Reconciled the plugin skill count in `docs/install.md` (15 skills, including the `calibration-doctor`
  and `calibration-onboarding` flows).

## [0.2.0] - 2026-05-13

### Added

- `calibration-doctor` flow — ~5-second structural health check (JSON parses, hook scripts exist and
  are executable, frontmatter valid, MCP commands resolve).
- `calibration-onboarding` flow — stateless first-time setup guide.
- Feature-scoped and plugin-scoped `/calibrate` — audit a chosen subset of features, or a single
  plugin's footprint with a manifest-derived intent.
- Reports & artifacts UX for calibration runs (final report composed from run-folder files).

### Changed

- Parallelised the evaluator: it fans out to nine `calibration-feature-evaluator` (haiku) workers,
  one per feature, in a single tool-use block.
- Trimmed the worker agents and reconciled the `CLAUDE.md` guard rails with the shipped hooks/rules.

## [0.1.0] - 2026-05-13

### Added

- Initial `claude-calibration` plugin: the three-layer architecture (per-feature `calibrate-<feature>`
  bundles → planner/evaluator/calibrator worker agents → `/calibrate` orchestrator), with the
  `/calibration` dispatcher and `audit` / `diff` convenience flows.
- Nine per-feature calibration bundles (claude-md, rules, settings, skills, subagents, hooks, mcp,
  plugins, general), each shipping `SKILL.md`, `reference.md`, `scripts/{enumerate,lint}.sh`,
  `templates/`, and `examples/`.
- The recurrence → enforcement-creation flow: repeated findings are promoted to `kind: create` rows
  that scaffold a hook / rule / wrapper skill into the audited setup.
- Path-scoped `rules/` (the `signatures` catalogue + `dispatch` map) and two `PreToolUse` write-guard
  hooks (`calibrator-write-guard.sh`, `audit-write-guard.sh`).
- The grounding doc-set under `docs/` (one page per feature + reference pages).

[Unreleased]: https://github.com/odere-pro/claude-calibration/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/odere-pro/claude-calibration/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/odere-pro/claude-calibration/releases/tag/v0.1.0
