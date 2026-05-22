#!/usr/bin/env bash
# G6 — every shipped rule under rules/ has `paths:` frontmatter. (CRITICAL)
# A plugin-shipped rule without `paths:` loads always-on for every user who enables the plugin.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
while IFS= read -r f; do
  fm="$(gates_frontmatter "$f")"
  printf '%s\n' "$fm" | grep -qE '^paths:[[:space:]]*$' \
    || { echo "  FAIL: no 'paths:' frontmatter in $f"; fail=1; }
done < <(find rules -type f -name '*.md' | sort)

if [ "$fail" -ne 0 ]; then echo "G6 rules-have-paths: FAIL"; exit 1; fi
echo "G6 rules-have-paths: ok"
