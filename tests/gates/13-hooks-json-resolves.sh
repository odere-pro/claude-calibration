#!/usr/bin/env bash
# G13 — every command in hooks/hooks.json resolves to an existing, executable script. (CRITICAL)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

HJ="hooks/hooks.json"
[ -f "$HJ" ] || { echo "  FAIL: missing $HJ"; echo "G13 hooks-json-resolves: FAIL"; exit 1; }

fail=0
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  # take the first whitespace-delimited token (the script path) and strip the plugin-root prefix
  path="${cmd%% *}"
  path="${path#\$\{CLAUDE_PLUGIN_ROOT\}/}"
  if [ ! -f "$path" ]; then
    echo "  FAIL: hook command path not found: $path  (from: $cmd)"; fail=1
  elif [ ! -x "$path" ]; then
    echo "  FAIL: hook command not executable: $path"; fail=1
  fi
done < <(jq -r '.hooks[][].hooks[].command' "$HJ" 2>/dev/null)

if [ "$fail" -ne 0 ]; then echo "G13 hooks-json-resolves: FAIL"; exit 1; fi
echo "G13 hooks-json-resolves: ok"
