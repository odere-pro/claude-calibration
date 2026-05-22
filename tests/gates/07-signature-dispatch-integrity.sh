#!/usr/bin/env bash
# G7 — the signatures <-> dispatch <-> bundles contract holds. (CRITICAL)
#   (a) every signature referenced in dispatch.md exists in signatures.md
#   (b) the calibrate-* bundles are exactly the nine features, each with the required layout
# A signature missing from any of these is invisible somewhere in the pipeline.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

SIG="rules/signatures.md"
DIS="rules/dispatch.md"
fail=0

token_re="(${GATES_SIG_PREFIXES}):[a-z0-9-]+"

catalogued="$(grep -oE "$token_re" "$SIG" | sort -u)"
referenced="$(grep -oE "$token_re" "$DIS" | sort -u)"

while IFS= read -r sig; do
  [ -n "$sig" ] || continue
  if ! printf '%s\n' "$catalogued" | grep -qxF "$sig"; then
    echo "  FAIL: dispatch.md references '$sig' but it is not catalogued in signatures.md"
    fail=1
  fi
done <<EOF
$referenced
EOF

# (b) bundle set + layout
for feat in $GATES_FEATURES; do
  d="skills/calibrate-${feat}"
  if [ ! -d "$d" ]; then
    echo "  FAIL: missing bundle dir $d"; fail=1; continue
  fi
  for required in SKILL.md reference.md scripts/enumerate.sh scripts/lint.sh; do
    [ -f "$d/$required" ] || { echo "  FAIL: $d missing $required"; fail=1; }
  done
  if ! ls "$d"/templates/*.tmpl >/dev/null 2>&1; then
    echo "  FAIL: $d has no templates/*.tmpl"; fail=1
  fi
  if ! find "$d/examples" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -q .; then
    echo "  FAIL: $d has no examples/<case>/ dir"; fail=1
  fi
done

# no stray calibrate-* bundle outside the nine
expected_dirs=""
for feat in $GATES_FEATURES; do expected_dirs="${expected_dirs} skills/calibrate-${feat}"; done
while IFS= read -r d; do
  case " $expected_dirs " in
    *" $d "*) : ;;
    *) echo "  FAIL: unexpected bundle dir $d (not one of the nine features)"; fail=1 ;;
  esac
done < <(find skills -mindepth 1 -maxdepth 1 -type d -name 'calibrate-*' | sort)

if [ "$fail" -ne 0 ]; then echo "G7 signature-dispatch-integrity: FAIL"; exit 1; fi
echo "G7 signature-dispatch-integrity: ok"
