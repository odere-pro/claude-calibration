#!/usr/bin/env bash
# G4 — every shipped SKILL.md sets `disable-model-invocation: true`. (CRITICAL)
# Non-negotiable: Claude must never auto-fire a calibration skill (zero standing context).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
while IFS= read -r f; do
  fm="$(gates_frontmatter "$f")"
  printf '%s\n' "$fm" | grep -qE '^disable-model-invocation:[[:space:]]*true[[:space:]]*$' \
    || { echo "  FAIL: missing 'disable-model-invocation: true' in $f"; fail=1; }
done < <(find skills -type f -name 'SKILL.md' | sort)

if [ "$fail" -ne 0 ]; then echo "G4 skill-dmi: FAIL"; exit 1; fi
echo "G4 skill-dmi: ok"
