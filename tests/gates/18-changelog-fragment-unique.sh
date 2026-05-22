#!/usr/bin/env bash
# G18 — changelog fragment numbers are unique. (CRITICAL)
# Every changelog/<NN>-<slug>.md must carry a distinct <NN> prefix — the README convention is
# "one greater than the highest already used". A collision means two in-flight PRs picked the same
# number; the fragment-per-PR scheme prevents content conflicts but not number reuse, so this gate
# guards it. Fix: renumber the later fragment to the next free NN (see changelog/README.md).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

# Collect the NN prefix of every numbered fragment, then surface any that repeat.
dupes="$(
  for f in changelog/[0-9][0-9]-*.md; do
    [ -e "$f" ] || continue
    b="$(basename -- "$f")"
    printf '%s\n' "${b%%-*}"
  done | sort | uniq -d
)"

if [ -n "$dupes" ]; then
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    echo "  FAIL: duplicate fragment number '$n' — $(printf '%s ' changelog/"$n"-*.md)"
  done <<EOF
$dupes
EOF
  echo "  fix: renumber the later fragment to the next free NN (see changelog/README.md)"
  echo "G18 changelog-fragment-unique: FAIL"
  exit 1
fi

echo "G18 changelog-fragment-unique: ok"
