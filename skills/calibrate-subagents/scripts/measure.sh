#!/usr/bin/env bash
# measure.sh — print TSV measurements for subagent .md files.
# Usage: measure.sh <agent.md> [agent.md ...]
# Output (header + one row per file):
#   path  body_lines  name_len  has_tools  has_model  has_description  has_mcp_servers  has_max_turns
set -euo pipefail
printf 'path\tbody_lines\tname_len\thas_tools\thas_model\thas_description\thas_mcp_servers\thas_max_turns\n'

for f in "$@"; do
  if [ ! -f "$f" ]; then
    printf '%s\t-\t-\t-\t-\t-\t-\t-\n' "$f"
    continue
  fi

  body_lines=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==2{print}' "$f" | wc -l | tr -d ' ')
  fm=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==1' "$f")

  name=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d ' "')
  has_tools=$(printf       '%s\n' "$fm" | grep -qE '^tools:'         && echo yes || echo no)
  has_model=$(printf       '%s\n' "$fm" | grep -qE '^model:'         && echo yes || echo no)
  has_desc=$(printf        '%s\n' "$fm" | grep -qE '^description:'   && echo yes || echo no)
  has_mcp=$(printf         '%s\n' "$fm" | grep -qE '^mcpServers:'    && echo yes || echo no)
  has_maxturns=$(printf    '%s\n' "$fm" | grep -qE '^maxTurns:'      && echo yes || echo no)

  printf '%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\n' \
    "$f" "$body_lines" "${#name}" "$has_tools" "$has_model" "$has_desc" "$has_mcp" "$has_maxturns"
done
