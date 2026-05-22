#!/usr/bin/env bash
# G5 — every agents/*.md declares name, description, tools, and model. (CRITICAL)
# An omitted `tools:` makes a subagent inherit every tool (incl. MCP) — the repo's own
# `subagent:missing-tools` anti-pattern.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
while IFS= read -r f; do
  fm="$(gates_frontmatter "$f")"
  for key in name description tools model; do
    printf '%s\n' "$fm" | grep -qE "^${key}:[[:space:]]*\S" \
      || { echo "  FAIL: no '${key}' in $f"; fail=1; }
  done
done < <(find agents -type f -name '*.md' -not -name 'CLAUDE.md' | sort)

if [ "$fail" -ne 0 ]; then echo "G5 agent-frontmatter: FAIL"; exit 1; fi
echo "G5 agent-frontmatter: ok"
