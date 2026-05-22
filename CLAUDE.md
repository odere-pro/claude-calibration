# claude-calibration — plugin development

This repo is the source for the `claude-calibration` Claude Code plugin. It is **not** an
application — every file under here ships to end users when the plugin is installed.

## What ships

- `.claude-plugin/plugin.json` — manifest (version of record)
- `.claude-plugin/marketplace.json` — single-plugin marketplace manifest (`source: "./"`); version
  is omitted here on purpose — `plugin.json` wins
- `skills/calibrate*/` — orchestrators + 9 per-feature bundles
- `skills/calibration-*/` — top-level flows: `calibration` (dispatcher), `calibration-audit`,
  `calibration-diff`, `calibration-doctor`, `calibration-onboarding`
- `agents/calibration-*.md` — 4 worker agents: planner, evaluator, calibrator, and
  `calibration-feature-evaluator` (haiku worker the evaluator fans out to in parallel)
- `rules/{signatures,dispatch}.md` — canonical signature catalogue + dispatch map
- `hooks/{hooks.json,calibrator-write-guard.sh,audit-write-guard.sh}` — `PreToolUse` write-guards
- `docs/` — human-readable rubric (the doc-set the plugin grades against)

## What doesn't

- `.claude/` (this dir's project config — only for plugin authors, not loaded for end users)
- `tmp/` (scratch)
- `.claude/calibration/` (run artifacts)

> Note: Claude Code clones the **whole** repo into the plugin cache — there is no ship-whitelist or
> `.claudeignore`. So author-only files (`.claude/`, `tests/gates/`, `.github/`, `CONTRIBUTING.md`,
> `SECURITY.md`, `CHANGELOG.md`, `SOFTWARE-3-0.md`, …) are copied but never *loaded* — Claude only
> loads recognized component dirs (`skills/`, `agents/`, `rules/`, `hooks/`, `commands/`) plus the
> manifest. They cost nothing at runtime, so we don't add a build/packaging step to strip them.

## Pointers

- README for the user-facing pitch: [`README.md`](README.md)
- Docs index (the rubric): [`docs/README.md`](docs/README.md)
- Plugin lifecycle & usage: [`docs/install.md`](docs/install.md), [`docs/usage.md`](docs/usage.md)

## Agent routing

The 4 worker agents (`calibration-planner`, `calibration-evaluator`, `calibration-calibrator`,
`calibration-feature-evaluator`) are invoked exclusively by the orchestrator skill at
`skills/calibration/SKILL.md`. No root `AGENTS.md` is needed; routing is encoded in the
orchestrator's dispatch logic, not a routing table.

## House rules

Detailed plugin-development rules live in `.claude/rules/plugin-dev.md` (path-scoped to plugin
internals; loads on-demand).

Guard rails (each labelled by enforcement mechanism):

- **[signature-tracked]** Don't rename a pattern signature — breaks recurrence history. See
  `rules/signatures.md`; signature `rule:should-be-skill` tracks this class of violation.
- **[hook-guarded]** Don't break the `signature → bundle` map in `rules/dispatch.md` —
  signature `general:must-rule-with-no-hook` flags it and `hooks/calibrator-write-guard.sh`
  blocks unauthorised writes during a calibrator session.
- **[advisory]** Don't skip `/reload-plugins` after editing under `--plugin-dir`. No hook
  enforces this; it's a workflow reminder.

## Vocabulary

Two files are authoritative; everything else defers to them:

- `rules/signatures.md` — the **pattern-signature catalogue** (`<feature>:<short-name>`). Signatures
  are a public contract: a rename breaks cross-run recurrence history. Adding/changing one means
  syncing **four** places — `signatures.md`, the owning bundle's `reference.md`, its
  `scripts/lint.sh` emit, and `rules/dispatch.md`. See [`rules/CLAUDE.md`](rules/CLAUDE.md).
- `docs/glossary.md` — the **term** vocabulary (feature, scope, layer, bundle, recurrence,
  enforcement-creation, orchestrator/dispatcher/flow, run folder, …).

## Gate map

`bash tests/gates/run-all.sh` before any PR. Each gate is a small standalone script under
`tests/gates/`; CRITICAL gates fail CI, advisory ones only warn.

| Gate | Protects | Typical failure |
| ---- | -------- | --------------- |
| G1 `01-json-parses` | every shipped `*.json` is valid | a typo in `plugin.json` / `hooks.json` |
| G2 `02-marketplace-shape` | `marketplace.json` shape; entry name matches `plugin.json`; no `version` | drift between the two manifests |
| G3 `03-skill-frontmatter` | every `SKILL.md` has `name` + `description` | missing frontmatter |
| G4 `04-skill-dmi` | every shipped skill is `disable-model-invocation: true` | a skill that can auto-fire |
| G5 `05-agent-frontmatter` | `agents/*.md` declare `name`/`description`/`tools`/`model` | a tool-inheriting agent |
| G6 `06-rules-have-paths` | every shipped rule has `paths:` | an always-on rule for every user |
| G7 `07-signature-dispatch-integrity` | dispatch signatures ∈ catalogue; 9 bundles well-formed | signature ↔ dispatch ↔ bundle drift |
| G8 `08-shellcheck` | all shell scripts lint clean (`-S error`) | a shell bug |
| G9 `09-no-absolute-paths` | no `/Users/` `/home/` in shipped files | a leaked machine path |
| G10 `10-secret-scan` | no token-shaped secrets in shipped files | a leaked credential |
| G11 `11-changelog-version` | `CHANGELOG.md` has the `plugin.json` version section | changelog/version drift |
| G12 `12-hooks-no-remote` | no `curl`/`wget`/remote `npx` in hooks | network on the hot path |
| G13 `13-hooks-json-resolves` | `hooks.json` commands resolve to executables | broken hook wiring |
| G14 `14-doc-links` | no dangling intra-doc `.md` links | a broken doc/briefing link |
| G15 `15-markdown-lint` (advisory) | markdown style | style nit |
| G16 `16-changelog-fragment-present` | a PR with non-doc changes adds a `changelog/` fragment | missing fragment |

## Test / verify quick-recipes

```bash
bash tests/gates/run-all.sh                       # full gate suite
bash tests/gates/07-signature-dispatch-integrity.sh   # one gate, standalone
bash scripts/changelog-aggregate.sh               # preview pending changelog fragments

bash tests/eval/run-eval.sh --scope shipped --durability   # deterministic snapshot: floor + scoped lint + durability
bash tests/eval/compare-eval.sh --vs-baseline              # track improvement/regression vs tests/eval/baseline.json
bash tests/eval/run-eval.sh --scope all --no-write         # diagnostic: what an unscoped audit would see (incl. cache)

claude --plugin-dir .                             # load the plugin against itself, then in-session:
#   /reload-plugins                               #   pick up edits
#   /claude-calibration:calibration-audit         #   read-only end-to-end smoke
#   /calibrate cost                               #   load-bearing on calibrate-general/scripts/lint.sh
#   /calibrate "audit this plugin's setup"        #   dogfood the full loop
```

## Source layout

| Path | Role | Ships? |
| ---- | ---- | ------ |
| `.claude-plugin/` | `plugin.json` + `marketplace.json` | yes |
| `skills/` | orchestrator (`calibrate`), dispatcher (`calibration`), 4 flows, 9 per-feature bundles | yes |
| `agents/` | the 4 worker subagents | yes |
| `rules/` | `signatures.md` + `dispatch.md` (path-scoped) | yes |
| `hooks/` | the two `PreToolUse` write-guards | yes |
| `docs/` | the rubric the plugin grades against | yes |
| `tests/gates/` | the CI validation suite (`run-all.sh` + numbered gates) | author-only |
| `tests/eval/` | deterministic eval harness (`run-eval.sh` / `compare-eval.sh` + `baseline.json` + `history.jsonl`) | author-only |
| `scripts/` | maintenance scripts (`changelog-aggregate.sh`) | author-only |
| `changelog/` | per-PR changelog fragments | author-only |
| `.claude/` | this repo's own project config + maintenance skills/agent | author-only |
| `.github/` | CI/release workflows + issue/PR templates | author-only |

## Where to read before editing

| Editing… | Read first |
| -------- | ---------- |
| a `calibrate-*` bundle | [`skills/CLAUDE.md`](skills/CLAUDE.md) + that bundle's `reference.md` + `.claude/rules/plugin-dev.md` |
| a pattern signature | [`rules/CLAUDE.md`](rules/CLAUDE.md) (the four-places-in-sync rule) |
| a worker agent | [`agents/CLAUDE.md`](agents/CLAUDE.md) |
| a write-guard hook | [`hooks/CLAUDE.md`](hooks/CLAUDE.md) |
| a CI gate | [`tests/gates/CLAUDE.md`](tests/gates/CLAUDE.md) |
| the rubric vs upstream docs | run `/docs-status` → `/docs-update` → `/plugin-update` (author-only skills under `.claude/skills/`) |
