# claude-calibration — plugin development

This repo is the source for the `claude-calibration` Claude Code plugin. It is **not** an
application — every file under here ships to end users when the plugin is installed.

## What ships

- `.claude-plugin/plugin.json` — manifest (version of record)

This repo no longer ships its own `marketplace.json`. Distribution is via the external
[`odere-pro`](https://github.com/odere-pro/claude-software-3-0-marketplace) aggregator marketplace,
which lists this plugin by `github` source — install with `claude-calibration@odere-pro`.
- `skills/calibrate*/` — orchestrators + 9 per-feature bundles
- `skills/calibration-*/` — top-level flows: `calibration` (dispatcher), `calibration-audit`,
  `calibration-diff`, `calibration-track`, `calibration-flow`, `calibration-doctor`,
  `calibration-onboarding`
- `agents/calibration-*.md` — 5 worker subagents: planner, evaluator, calibrator,
  `calibration-feature-evaluator` (haiku worker the evaluator fans out to in parallel), and
  `calibration-flow-evaluator` (sonnet worker the `/calibration-flow` behavioural flow spawns)
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

The 5 worker subagents (`calibration-planner`, `calibration-evaluator`, `calibration-calibrator`,
`calibration-feature-evaluator`, `calibration-flow-evaluator`) are invoked exclusively by the skill
layer — the `/calibrate` orchestrator and the standalone flows (`calibration-flow` spawns
`calibration-flow-evaluator`); never by the user directly. No root `AGENTS.md` is needed; routing is
encoded in the
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
| G17 `17-glossary-consistency` | `docs/glossary.md` defines the power-word vocabulary (`agent`/`subagent` distinct) AND prose uses it — drift is caught | a power word with no entry, or a banned synonym in prose (e.g. a worker subagent written as a plain `agent`) |
| G18 `18-changelog-fragment-unique` | every `changelog/<NN>-<slug>.md` has a distinct `<NN>` | two in-flight PRs picked the same fragment number |
| G19 `19-flow-fixture-integrity` | behavioural-flow fixtures have `input/` + a parseable `expected.md` oracle naming only catalogued signatures; the scorer can score each shipped example | a fixture with no `expected.md`, an unparseable oracle, or a signature not in `signatures.md` |
| G20 `20-plugin-filter` | the `skills/lib/` plugin-filter helpers extract names, apply allow/block + scope correctly, and the resolver normalises `--plugins` / `config.json` | a regression in plugin allow/block-list scoping |

## Test / verify quick-recipes

```bash
bash tests/gates/run-all.sh                       # full gate suite
bash tests/gates/07-signature-dispatch-integrity.sh   # one gate, standalone
bash scripts/changelog-aggregate.sh               # preview pending changelog fragments

bash tests/eval/run-eval.sh --scope shipped --durability   # deterministic snapshot: floor + scoped lint + durability
bash tests/eval/compare-eval.sh --vs-baseline              # track improvement/regression vs tests/eval/baseline.json
bash tests/eval/run-eval.sh --scope all --no-write         # diagnostic: what an unscoped audit would see (incl. cache)
bash tests/eval/score-flow-cases.sh                        # deterministic unit tests for the behavioural-flow scorer (no LLM)

claude --plugin-dir .                             # load the plugin against itself, then in-session:
#   /reload-plugins                               #   pick up edits
#   /claude-calibration:calibration-audit         #   read-only end-to-end smoke
#   /calibrate cost                               #   load-bearing on calibrate-general/scripts/lint.sh
#   /calibrate "audit this plugin's setup"        #   dogfood the full loop
```

## Source layout

| Path | Role | Ships? |
| ---- | ---- | ------ |
| `.claude-plugin/` | `plugin.json` (the manifest) | yes |
| `skills/` | orchestrator (`calibrate`), dispatcher (`calibration`), 6 flows, 9 per-feature bundles | yes |
| `skills/lib/` | shared shell helpers (`plugin-filter.sh` sourced by bundle `enumerate.sh`; `resolve-plugin-filter.sh` called by `calibrate`/audit/diff) — not a skill, no `SKILL.md` | yes |
| `agents/` | the 5 worker subagents | yes |
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
| a worker subagent | [`agents/CLAUDE.md`](agents/CLAUDE.md) |
| a write-guard hook | [`hooks/CLAUDE.md`](hooks/CLAUDE.md) |
| a CI gate | [`tests/gates/CLAUDE.md`](tests/gates/CLAUDE.md) |
| the rubric vs upstream docs | run `/docs-status` → `/docs-update` → `/plugin-update` (author-only skills under `.claude/skills/`) |
