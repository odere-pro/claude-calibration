#!/usr/bin/env bash
# G3 — every skills/**/SKILL.md has `name` and `description` in its frontmatter. (CRITICAL)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
while IFS= read -r f; do
  fm="$(gates_frontmatter "$f")"
  printf '%s\n' "$fm" | grep -qE '^name:[[:space:]]*\S'        || { echo "  FAIL: no 'name' in $f"; fail=1; }
  printf '%s\n' "$fm" | grep -qE '^description:[[:space:]]*\S' || { echo "  FAIL: no 'description' in $f"; fail=1; }
done < <(find skills -type f -name 'SKILL.md' | sort)

if [ "$fail" -ne 0 ]; then echo "G3 skill-frontmatter: FAIL"; exit 1; fi
echo "G3 skill-frontmatter: ok"
