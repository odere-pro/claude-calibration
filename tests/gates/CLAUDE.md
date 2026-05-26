# CLAUDE.md — `tests/gates`

## Scope

The repo's CI validation suite: numbered shell gates (`NN-<slug>.sh`) that each assert one invariant.
Author-only (not shipped/loaded for plugin users). The full lookup of which gate guards what lives in
the root [`../../CLAUDE.md`](../../CLAUDE.md) "Gate map".

- `NN-<slug>.sh` — one gate per invariant, numbered (01–19).
- `run-all.sh` — runs every `[0-9][0-9]-*.sh` in order; non-zero exit from a gate fails the suite.
- `lib.sh` — shared helpers (`gates_repo_root`, `gates_frontmatter`, `GATES_FEATURES`,
  `GATES_SIG_PREFIXES`); sourced, never executed. **`GATES_SIG_PREFIXES` is the nine config
  features only** — the behavioural prefixes (`review`/`handoff`/`flow`) are deliberately excluded so
  G7 stays scoped to config; G19 (`19-flow-fixture-integrity.sh`) validates the behavioural family
  against the catalogue with its own local regex. Don't add them here or G7 will demand bundle
  ownership for a family that has none.
- `power-words.txt` — data sidecar for G17: the power-word catalogue; each term must be defined as a
  `**bold**` entry in `docs/glossary.md`.
- `forbidden-terms.txt` — data sidecar for G17: `<forbidden-ERE> => <canonical>` rules for phrases
  that are always wrong; G17 scans shipped/author prose for them (this is what catches usage drift).

## Convention

```sh
bash tests/gates/run-all.sh        # whole suite
bash tests/gates/NN-<slug>.sh      # one gate, standalone
```

Each gate: `set -euo pipefail`, source `lib.sh`, `cd "$(gates_repo_root)"`, do its check, print
`G<NN> <slug>: ok` (pass) or print `  FAIL: …` lines then `G<NN> <slug>: FAIL` and `exit 1`.

## Invariants you must not break

- **Numbering is unique and append-only.** Pick the next free `NN`; don't renumber existing gates
  (PR descriptions and the root Gate map reference numbers).
- **Exit codes are load-bearing.** `0` = pass *or advisory/skip*, non-zero = fail. `run-all.sh` fails
  the suite on any non-zero exit, so advisory gates (markdown lint) and not-applicable gates (the
  changelog-fragment gate with no base ref) must **exit 0** with a `SKIP`/advisory line.
- **CRITICAL vs advisory.** CRITICAL gates exit non-zero on violation; advisory gates only warn
  (always exit 0). Mark the mode in the header comment.
- **Source `lib.sh` for the repo root + frontmatter helpers** — don't re-derive them per gate.
- **`examples/` is intentionally excluded** by G9/G10 — before/after fixtures embody the
  anti-patterns on purpose (a fake secret, a placeholder `/Users/...` path).
- **Portable Bash.** macOS ships bash 3.2 — no `mapfile`/`readarray`; use `find … -exec` or `while read`.

## Adding a gate

1. Pick the next free `NN`; create `NN-<slug>.sh`, make it executable.
2. Header comment: one-line purpose + severity (CRITICAL / ADVISORY).
3. Source `lib.sh`; keep it < ~40 lines; CRITICAL gates use only `jq` + `shellcheck`.
4. Add a row to the root [`../../CLAUDE.md`](../../CLAUDE.md) "Gate map".
5. `bash tests/gates/run-all.sh` to confirm it cooperates.

## How to test this area

- `bash tests/gates/run-all.sh` — full suite.
- `shellcheck -S warning -x tests/gates/*.sh` — keep gate scripts clean (G8 lints them at `-S error`).

## When in doubt

The changelog-fragment gate (G16) pairs with [`../../changelog/README.md`](../../changelog/README.md)
and `../../scripts/changelog-aggregate.sh`.
