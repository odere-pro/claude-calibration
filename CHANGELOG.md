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

## [0.2.0] — 2026-06-01

### Added

- Target which plugins a calibration run audits with a plugin allow-list / block-list:
  `/calibrate --plugins foo,bar` (allow-list), `--plugins -baz` (block-list), or
  `--plugins global|local` (restrict by install scope), with the same available on
  `/claude-calibration:calibration-audit` and a persisted `.claude/calibration/config.json` default.
  The filter spans both globally-installed and locally-loaded plugins and applies everywhere the
  audit reaches into plugin caches (the `plugins`, `skills`, and `subagents` bundles), carried
  through the run as `plugin_filter` in `plan.md` and shown on the final report's Scope line. New
  shared shell helpers under `skills/lib/` (`plugin-filter.sh`, `resolve-plugin-filter.sh`) keep the
  parse and gating in one place; default (no filter) enumeration is byte-identical to before.

## [0.1.1] — 2026-05-26

### Added

- `1f84973` — Reference the odere-pro GitHub account in the manifests: add `owner.url` to `marketplace.json`, fix the `plugin.json` `author` block (`name` had held an email) into name/email/url, and point `homepage` at the repository.
- `ea809f7` — Make the calibrate self-audit return clean on a correctly-built repo by fixing the defects and false positives dogfooding surfaced: `calibrate-claude-md`'s `lint.sh` no longer aborts mid-loop under `set -e`/`pipefail` (honours the always-exit-0 contract) and only flags genuinely aspirational prose for `vague-rules` (skips markdown headers, fenced code, and precise modal prohibitions); the `subagents`/`rules`/`hooks` `enumerate.sh` scripts skip `CLAUDE.md`/`README.md` so memory/doc files aren't audited as components; the hooks script-scan no longer mistakes `case` labels, quoted strings, comments, and `break`/`continue`/`;;` for PATH commands; `skill:cli-not-wrapped` only fires when a skill has bare unscoped `Bash` (so it could actually shell out); and `general:nested-claude-md-conflict` now counts only nested `CLAUDE.md` the root `CLAUDE.md` doesn't index, so documented layering isn't flagged as sprawl.
- `5d489e1` — README badges + power-words glossary: add a shields badge row (incl. live `gates` + OpenSSF Scorecard), define the project's power-word vocabulary in `docs/glossary.md` (notably **agent** vs **subagent** as distinct terms — a subagent is an agent that runs in its own context window), and add gate G17 asserting the glossary defines that vocabulary.
- `5d489e1` — Add an author-only deterministic eval harness (`tests/eval/`): `run-eval.sh` scores the plugin's own shipped payload (gate floor + correctly-scoped lint + adversarial durability checks) into a versioned JSON snapshot, and `compare-eval.sh` diffs snapshots to track improvement/regression across runs, with the time series stored in `tests/eval/history.jsonl` + a blessed `baseline.json`.
- `5d489e1` — Harden the plugin via a self-calibration run: add CRITICAL gate **G18** (`18-changelog-fragment-unique`) asserting every `changelog/<NN>-<slug>.md` carries a distinct `<NN>` (and renumber the duplicate `02-readme-badges-glossary-gate` fragment to `03` so it passes), and make gate **G17** skip the gitignored `.claude/calibration/` run artifacts so a local self-calibration run no longer trips the glossary scan — closing two unenforced/over-broad spots the dogfood surfaced.
- `fd18948` — Track whether calibration improves a setup over iterations: add the `/calibration-track` flow and its `snapshot.sh` / `compare.sh` engine — a deterministic config-quality snapshot (doctor floor + signature-keyed lint over all nine features) compared vs a baseline anchored to the last PR merged onto `main` and vs the previous iteration, persisted in a local gitignored ledger and independent of `/calibrate`'s circular built-in delta.
- `57d9ecb` — Fix a `claude-md:contradicts-nested` false positive in `calibrate-claude-md`'s lint: it diffed a root `CLAUDE.md` against itself (relative-path string comparison) and read shell comments inside fenced code blocks as headings — now compares by inode identity (`-ef`) and strips fenced blocks before extracting headers, so the signature only fires on genuine cross-level header collisions.
- `1ce0d38` — Add `/calibration-flow`, a shipped behavioural-flow evaluation capability: it drives a multi-step workflow over a case set of golden fixtures and grades whether the chain delivers intent and keeps its handoffs sound (node recall/precision, edge `handoff:*` contracts, flow intent), reusing the existing severity/signature/recurrence vocabulary. The verdict comes from a pure, deterministic scorer (`score-flow.sh`) — no LLM, no network — so it can be wired as both a CI gate (G19, via `lint-fixtures.sh`) and an on-demand run, with a `calibration-flow-evaluator` worker producing the findings the scorer judges.

## [0.1.0] — 2026-05-22

First public release. Everything below ships in `v0.1.0`.

### Added

- `0ab7a1d` — The `claude-calibration` plugin: a three-layer architecture (per-feature
  `calibrate-<feature>` bundles → planner / evaluator / calibrator worker agents → the `/calibrate`
  orchestrator), where `/calibrate` runs an evaluate → plan → calibrate → re-evaluate loop against a
  stated or guessed intent. Nine per-feature bundles (each `disable-model-invocation: true` for zero
  standing context), and the recurrence → enforcement-creation move that promotes repeated findings
  into a `kind: create` row scaffolding a new hook / rule / wrapper skill into the audited setup.
- `e63268b` — Full scaffolding so the plugin runs end-to-end against itself: the planner + evaluator
  worker agents (init/improve and baseline/delta passes), nine `docs/features/*.md` rubric pages each
  `reference.md` cites as source of truth, every bundle in the standard layout (`SKILL.md`,
  `reference.md`, `scripts/{enumerate,lint}.sh`, `templates/`, `examples/`), and the project `.claude/`
  (settings, `plugin-dev.md`) scoped to plugin internals.
- `e48332a` — Reports & artifacts UX: `plan.md` gains a `## Contents` progress + artifacts block,
  improvement-plan rows gain a `status` column (`pending|applying|done|partial|skipped`), the
  `## Intent` section captures normalized intent + `Success looks like:` criteria, evaluator reports
  slim to tables + source links, and a summary + close gate (`close|keep|skip`) prunes intermediates
  and bakes a `## Summary` into `plan.md`.
- `3ce7949` — Parallelised the evaluator: a new `calibration-feature-evaluator` (haiku) worker audits
  one feature each, and the parent evaluator fans out nine in a single tool-use block, merges the
  drafts, and composes the cross-feature reports — wall-clock drops from ~9× to ~1×, with a sequential
  fallback when nested-agent spawning is unavailable.
- `42b8095` — Two top-level flow skills: `calibration-doctor` (a ~5-second structural health check —
  JSON parses, hook scripts exist + are executable, frontmatter valid, MCP commands resolve) and
  `calibration-onboarding` (a stateless, read-only first-time setup guide that detects config state ×
  project stack and recommends one minimal next step).
- `2b6dcec`, `93d889e`, `8204722` — The grounding doc-set: a Claude Code configuration reference,
  restructured into a vertical one-page-per-feature set on a shared template (Definition → Scope →
  Configure → Validate → Improve → Sources) with a glossary, then expanded with 1–3-sentence "what it
  does" cells and per-feature recommendation tables. Facts grounded in `code.claude.com/docs/*` and
  `agents.md`; every page carries a `## Sources` block.
- `61b8fba` — Marketplace distribution + repo hardening: `.claude-plugin/marketplace.json`
  (`source: "./"`, version omitted so `plugin.json` stays the source of truth) so the plugin installs
  via `/plugin marketplace add odere-pro/claude-calibration` + `/plugin install claude-calibration@odere-pro`;
  `LICENSE` (MIT), `SOFTWARE-3-0.md`, `docs/glossary.md`, `docs/RELEASING.md`; the governance set
  (`CONTRIBUTING`, `SECURITY`, `CODE_OF_CONDUCT`, `SUPPORT`, `.github/` issue + PR templates); and the
  `tests/gates/` validation suite wired through `.github/workflows/ci.yml`, plus a tag-triggered
  `.github/workflows/release.yml`.
- `8ed12d2` — Two methodology pages: `docs/self-calibration.md` (how the plugin evaluates a setup end
  to end — the four flows, the 6-phase loop, worker agents + models, signatures/dispatch, and the
  write-guards) and `docs/evaluating-agentic-workflows.md` (evaluating multi-agent / multi-skill
  workflows at the node / edge / flow levels, with a PR code-review pipeline as the lead example).
- `2ced490` — A complete `CHANGELOG.md` plus the fragment-per-PR system (`changelog/`,
  `scripts/changelog-aggregate.sh`, gate `16-changelog-fragment-present.sh`); an enriched root
  `CLAUDE.md` (Vocabulary, Gate map, quick-recipes, Source layout, "where to read before editing");
  `skillOverrides` in `.claude/settings.json`; the maintenance skills under `.claude/skills/`
  (`docs-status`, `docs-update`, `plugin-update`) + the `docs-fetcher` agent; and per-directory
  `CLAUDE.md` briefings for `skills/`, `agents/`, `rules/`, `hooks/`, `tests/gates/`.

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
- `61b8fba` — Repaired pre-existing dangling doc links (`general-setup.md`, `features/commands.md`,
  `reference/*`) by repointing to the legacy pages and linking them from the index; reconciled the
  plugin skill count in `docs/install.md` (15 skills / four flows).
- `3ebeb47` — Corrected the marketplace `owner.email` to `odere.pro@gmail.com`.

[Unreleased]: https://github.com/odere-pro/claude-calibration/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/odere-pro/claude-calibration/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/odere-pro/claude-calibration/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/odere-pro/claude-calibration/releases/tag/v0.1.0
