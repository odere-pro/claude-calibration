#!/usr/bin/env bash
# G17 — docs/agents/skills use the canonical glossary vocabulary, not non-canonical synonyms. (CRITICAL)
# Each rule in glossary-aliases.txt maps a forbidden term (ERE) to a canonical one that must exist in
# docs/glossary.md; the gate fails on any forbidden term found in *.md under docs/, agents/, skills/.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

ALIASES="tests/gates/glossary-aliases.txt"
GLOSSARY="docs/glossary.md"
fail=0

[ -f "$ALIASES" ]  || { echo "  FAIL: missing $ALIASES";  echo "G17 glossary-consistency: FAIL"; exit 1; }
[ -f "$GLOSSARY" ] || { echo "  FAIL: missing $GLOSSARY"; echo "G17 glossary-consistency: FAIL"; exit 1; }

while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  case "$line" in
    *' => '*) : ;;
    *) echo "  FAIL: malformed alias rule (no ' => '): $line"; fail=1; continue ;;
  esac
  forbidden="${line%% => *}"
  canonical="${line##* => }"

  # (a) keep the denylist tied to the glossary
  if ! grep -qiF -- "$canonical" "$GLOSSARY"; then
    echo "  FAIL: canonical term '$canonical' (alias rule) not found in $GLOSSARY"
    fail=1
  fi

  # (b) no shipped doc/agent/skill may use the forbidden term
  matches="$(grep -rniE --include='*.md' --exclude-dir=examples --exclude-dir=templates \
    -- "$forbidden" docs agents skills 2>/dev/null || true)"
  if [ -n "$matches" ]; then
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      echo "  FAIL: $hit  (use '$canonical')"
      fail=1
    done <<EOF
$matches
EOF
  fi
done < "$ALIASES"

if [ "$fail" -ne 0 ]; then echo "G17 glossary-consistency: FAIL"; exit 1; fi
echo "G17 glossary-consistency: ok"
