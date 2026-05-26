#!/usr/bin/env bash
# G19 — behavioural-flow fixtures + oracle integrity hold. (CRITICAL)
#   (a) every fixture case has input/ + a parseable expected.md naming only catalogued signatures
#   (b) the deterministic scorer can score each shipped example with a recorded actual.tsv (exit != 2)
# The behavioural prefixes (review|handoff|flow) live OUTSIDE GATES_SIG_PREFIXES on purpose: G7 owns
# the nine config features, G19 owns the behavioural family. Do not re-couple them in lib.sh.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

SIG="rules/signatures.md"
LINT="skills/calibration-flow/scripts/lint-fixtures.sh"
SCORE="skills/calibration-flow/scripts/score-flow.sh"
fail=0

# Collect fixture case dirs: shipped examples + author-only dogfood. Bash 3.2: no mapfile.
cases=""
for root in skills/calibration-flow/examples tests/eval/fixtures; do
  [ -d "$root" ] || continue
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    cases="${cases} ${d}"
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d | sort)
done

if [ -z "$cases" ]; then
  echo "G19 flow-fixture-integrity: ok (no fixtures)"
  exit 0
fi

# (a) integrity: a clean case set makes lint-fixtures emit nothing.
# shellcheck disable=SC2086
findings="$(bash "$LINT" --catalogue "$SIG" $cases || true)"
if [ -n "$findings" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    echo "  FAIL: $line"
    fail=1
  done <<EOF
$findings
EOF
fi

# (b) the scorer must SCORE each shipped example carrying a recorded actual.tsv (exit 0|1, never 2).
for d in $cases; do
  [ -f "$d/actual.tsv" ] || continue
  af=""
  [ -f "$d/actual-flow.tsv" ] && af="--actual-flow $d/actual-flow.tsv"
  set +e
  # shellcheck disable=SC2086
  bash "$SCORE" --expected "$d/expected.md" --actual "$d/actual.tsv" $af --format tsv >/dev/null 2>&1
  rc=$?
  set -e
  if [ "$rc" -eq 2 ]; then
    echo "  FAIL: score-flow could not score $d (exit 2)"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then echo "G19 flow-fixture-integrity: FAIL"; exit 1; fi
echo "G19 flow-fixture-integrity: ok"
