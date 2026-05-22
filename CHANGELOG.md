# Changelog

All notable changes to `claude-calibration` are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The version of record is `.claude-plugin/plugin.json` → `version`. Each release is a git tag
`vX.Y.Z`; marketplace consumers update by re-pulling the tagged commit. See
[`docs/RELEASING.md`](docs/RELEASING.md) for the release procedure.

> Pending entries live as fragments under [`changelog/`](changelog/README.md). Run
> `bash scripts/changelog-aggregate.sh` for a dry-run preview, or `--apply` to inline them into
> `[Unreleased]` (done in the release PR).

## [Unreleased]

### Added

- `61b8fba` — Marketplace distribution + repo hardening: `.claude-plugin/marketplace.json`
  (`source: "./"`, version omitted so `plugin.json` stays the source of truth) so the plugin installs
  via `/plugin marketplace add odere-pro/claude-calibration` + `/plugin install claude-calibration@odere-pro`;
  `LICENSE` (MIT), `CHANGELOG.md`, `SOFTWARE-3-0.md`, `docs/glossary.md`, `docs/RELEASING.md`; the
  governance set (`CONTRIBUTING`, `SECURITY`, `CODE_OF_CONDUCT`, `SUPPORT`, `.github/` issue + PR
  templates); and the `tests/gates/` validation suite (`run-all.sh` + 15 numbered gates) wired through
  `.github/workflows/ci.yml`, plus a tag-triggered `.github/workflows/release.yml`.
- `8ed12d2` — Two methodology pages: `docs/self-calibration.md` (how the plugin evaluates a setup end
  to end — the four flows, the 6-phase loop, worker agents + models, signatures/dispatch, and the
  write-guards) and `docs/evaluating-agentic-workflows.md` (evaluating multi-agent / multi-skill
  workflows at the node / edge / flow levels, with a PR code-review pipeline as the lead example).

### Changed

- `61b8fba` — Led the install docs with the marketplace command and reconciled the plugin skill count
  in `docs/install.md` (15 skills / four flows, including `calibration-doctor` and `calibration-onboarding`).

### Fixed

- `61b8fba` — Repaired pre-existing dangling doc links (`general-setup.md`, `features/commands.md`,
  `reference/*`) by repointing to the legacy pages and linking them from the index; restored the
  dangling `docs/glossary.md` link referenced by `docs/README.md`, `docs/install.md`, and `docs/usage.md`.
- `3ebeb47` — Corrected the marketplace `owner.email` to `odere.pro@gmail.com`.

## [0.2.0] — 2026-05-13

### Added

- `0ab7a1d` — The `claude-calibration` plugin: a three-layer architecture (per-feature
  `calibrate-<feature>` bundles → planner / evaluator / calibrator worker agents → the `/calibrate`
  orchestrator), where `/calibrate` runs an evaluate → plan → calibrate → re-evaluate loop against a
  stated or guessed intent. Nine per-feature bundles (each `disable-model-invocation: true` for zero
  standing context), and the recurrence → enforcement-creation move that promotes repeated findings
  into a `kind: create` row scaffolding a new hook / rule / wrapper skill into the audited setup.
- `e63268b` — Completed the scaffolding so the plugin runs end-to-end against itself: the
  planner + evaluator worker agents (init/improve and baseline/delta passes), nine `docs/features/*.md`
  rubric pages each `reference.md` cites as source of truth, every bundle in the standard layout
  (`SKILL.md`, `reference.md`, `scripts/{enumerate,lint}.sh`, `templates/`, `examples/`), and the
  minimal project `.claude/` (settings, `plugin-dev.md`) scoped to plugin internals.
- `e48332a` — Plan A — reports & artifacts UX: `plan.md` gains a `## Contents` progress + artifacts
  block, improvement-plan rows gain a `status` column (`pending|applying|done|partial|skipped`), the
  `## Intent` section captures normalized intent + `Success looks like:` criteria, evaluator reports
  slim to tables + source links, and a Phase 8 summary + close gate (`close|keep|skip`) prunes
  intermediates and bakes a `## Summary` into `plan.md`.
- `3ce7949` — Plan B — parallelised the evaluator: a new `calibration-feature-evaluator` (haiku)
  worker audits one feature each, and the parent evaluator fans out nine in a single tool-use block,
  merges the drafts, and composes the cross-feature reports — wall-clock drops from ~9× to ~1× with a
  sequential fallback when nested-agent spawning is unavailable.
- `42b8095` — Plan C — two top-level flow skills: `calibration-doctor` (a ~5-second structural health
  check — JSON parses, hook scripts exist + are executable, frontmatter valid, MCP commands resolve)
  and `calibration-onboarding` (a stateless, read-only first-time setup guide that detects config
  state × project stack and recommends one minimal next step).
- `2b6dcec`, `93d889e`, `8204722` — The grounding doc-set: an initial Claude Code configuration
  reference, restructured into a vertical one-page-per-feature set on a shared template
  (Definition → Scope → Configure → Validate → Improve → Sources) with a glossary, then expanded with
  1–3-sentence "what it does" cells and per-feature recommendation tables. Facts grounded in
  `code.claude.com/docs/*` and `agents.md`; every page carries a `## Sources` block.

### Changed

- `6ad8ba3` — Self-calibration pass: trimmed the evaluator (253 → 138 lines) and planner
  (215 → 157 lines), and reconciled `CLAUDE.md` — replaced the `Do not:` block with enforcement-labelled
  **Guard rails** (`[signature-tracked]` / `[hook-guarded]` / `[advisory]`), added an `## Agent routing`
  section, and replaced a hardcoded absolute path with `$PROJECT_DIR`.

### Fixed

- `d45a39f` — Self-harden: applied `/calibrate` findings against the plugin's own setup — scoped
  `allowed-tools` across 12 `SKILL.md` files (no bare `Bash`/`Write`/`Edit`; `calibrate-skills` wraps
  `gh` as `Bash(gh *)`), reframed `rules/{signatures,dispatch}.md` numbered lists as tables, replaced
  bare `*)` catch-alls in the write-guards with explicit allow-patterns, and added the
  `.claude/hooks/plugin-dev-guard.sh` PreToolUse enforcement scaffold.

[Unreleased]: https://github.com/odere-pro/claude-calibration/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/odere-pro/claude-calibration/releases/tag/v0.2.0
