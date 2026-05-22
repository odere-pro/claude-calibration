# CLAUDE.md — `tests/eval`

## Scope

The **deterministic calibration eval harness**: author-only instruments that measure *this plugin's
own* shipped payload against the canonical "did calibration improve results?" measure, and store the
result so improvement / regression is trackable over time. Author-only (not shipped/loaded for plugin
users; `tests/` is absent from the calibrator allow-list, so it's a true floor the calibrator can't edit).

Why this exists, not the built-in delta: the plugin's before→after severity-count delta is **circular**
(the same evaluator + rubric the calibrator optimizes against) and non-deterministic. This harness
measures only signals that are **deterministic, correctly-scoped, and independent of what the
calibrator optimizes** — see [`../../docs/self-calibration.md`](../../docs/self-calibration.md).

## Map

```
tests/eval/
├── lib-eval.sh      # shared helpers; sources ../gates/lib.sh (gates_repo_root, gates_frontmatter)
├── run-eval.sh      # produce one snapshot: floor + scoped lint + (optional) durability
├── compare-eval.sh  # diff two snapshots → before→after table + regression verdict (exit 1 on regress)
├── baseline.json    # the blessed reference snapshot (tracked)
├── history.jsonl    # append-only one-line-per-run ledger = the time series (tracked)
└── snapshots/       # per-run full JSON snapshots (gitignored)
```

The three measured layers:

1. **floor** — runs every `../gates/[0-9][0-9]-*.sh`; records per-gate exit + the pass/fail tally. A
   gate going green→red is the regression veto.
2. **scoped lint** — each `skills/calibrate-*/scripts/lint.sh` over the **true shipped payload only**
   (`--scope shipped`, default): `skills/*/SKILL.md`, `agents/calibration-*.md`, `rules/*.md`
   (≠ CLAUDE.md), `hooks/*.sh`+`hooks.json`, root `CLAUDE.md`, `.claude-plugin/plugin.json`, repo root
   for `general`. `--scope all` runs the bundles' `enumerate.sh` verbatim (sweeps user config + other
   plugins' cache) — a diagnostic, never the tracked baseline.
3. **durability** — `--durability`: re-introduces a fixed anti-pattern on a copy and confirms a shipped
   guard/gate still blocks it (dmi-strip detection, both write-guards → exit 2, a positive control, and
   a repo-untouched meta-check). Runs entirely in a `mktemp -d` sandbox.

## Convention

```sh
bash tests/eval/run-eval.sh --scope shipped --durability   # write a snapshot + ledger line
bash tests/eval/run-eval.sh --scope all --no-write          # diagnostic: what an unscoped run sees
bash tests/eval/compare-eval.sh --vs-baseline               # current vs blessed baseline.json
bash tests/eval/compare-eval.sh                             # last two ledger snapshots
bash tests/eval/compare-eval.sh A.json B.json [--strict]    # explicit pair
```

## Invariants you must not break

- **Author-only.** Stays under `tests/`; never becomes a shipped component (no `skills/`/`agents/`
  entry). It IS shellchecked by gate **G8** (`-S error -x` covers `tests/`), so keep it clean.
- **Portable Bash 3.2.** No `mapfile`/`readarray`; `printf` for all emission; greps that may not match
  get `|| true` under `set -Eeuo pipefail`.
- **Deterministic + scoped.** The tracked baseline is always `--scope shipped`. `--scope all` is
  machine-dependent (user `~/.claude` + plugin cache) and must never be committed as the baseline.
- **The harness never writes under the repo during measurement** except the snapshot + ledger at the
  end; the `--durability` sandbox is `mktemp -d` only (the `repo-untouched` check enforces this).
- **Snapshot schema is versioned** (`schema_version`); bump it on a breaking field change so
  `compare-eval.sh` can refuse mismatched pairs.

## How to test this area

- `shellcheck -S error -x tests/eval/*.sh` — what G8 enforces.
- `bash tests/eval/run-eval.sh --scope shipped --durability --no-write | jq empty` — valid JSON.
- `bash tests/gates/run-all.sh` — 16/16 (confirms the new scripts pass G8).

## When in doubt

The canonical measure and why the built-in delta is insufficient:
[`../../docs/self-calibration.md`](../../docs/self-calibration.md). The signature vocabulary the
snapshots key on: [`../../rules/signatures.md`](../../rules/signatures.md). Gate conventions the floor
layer mirrors: [`../gates/CLAUDE.md`](../gates/CLAUDE.md).
