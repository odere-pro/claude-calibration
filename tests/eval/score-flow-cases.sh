#!/usr/bin/env bash
# score-flow-cases.sh — deterministic unit tests for the behavioural-flow scorer.
# Runs skills/calibration-flow/scripts/score-flow.sh over each tests/eval/fixtures/<case>/ and diffs
# stdout + exit code against the committed golden want-score.txt (first line: "# want-exit: N").
# No LLM, no network — the no-LLM proof that the scoring seam is correct. Author-only (not shipped).
set -euo pipefail
ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT"
SCORE="skills/calibration-flow/scripts/score-flow.sh"
FIX="tests/eval/fixtures"
fail=0
total=0

[ -d "$FIX" ] || { echo "score-flow-cases: no fixtures at $FIX (nothing to check)"; exit 0; }

while IFS= read -r d; do
  [ -n "$d" ] || continue
  golden="$d/want-score.txt"
  if [ ! -f "$golden" ]; then
    echo "  FAIL: $d has no want-score.txt"; fail=1; continue
  fi
  total=$((total + 1))
  want_exit="$(sed -n 's/^# want-exit: //p' "$golden" | head -1)"
  want_out="$(grep -v '^# want-exit:' "$golden" || true)"
  set +e
  if [ -f "$d/actual-flow.tsv" ]; then
    got_out="$(bash "$SCORE" --expected "$d/expected.md" --actual "$d/actual.tsv" --actual-flow "$d/actual-flow.tsv" --format tsv)"
  else
    got_out="$(bash "$SCORE" --expected "$d/expected.md" --actual "$d/actual.tsv" --format tsv)"
  fi
  got_exit=$?
  set -e
  if [ "$got_exit" != "$want_exit" ]; then
    echo "  FAIL: $(basename "$d") exit $got_exit (want $want_exit)"; fail=1
  fi
  if [ "$got_out" != "$want_out" ]; then
    echo "  FAIL: $(basename "$d") output drift:"
    diff <(printf '%s\n' "$want_out") <(printf '%s\n' "$got_out") || true
    fail=1
  fi
done < <(find "$FIX" -mindepth 1 -maxdepth 1 -type d | sort)

if [ "$fail" -ne 0 ]; then echo "score-flow-cases: FAIL"; exit 1; fi
echo "score-flow-cases: ok ($total cases)"
