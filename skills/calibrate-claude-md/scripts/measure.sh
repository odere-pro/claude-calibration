#!/usr/bin/env bash
# measure.sh — TSV measurements for one or more CLAUDE.md / CLAUDE.local.md files.
# Usage: measure.sh <CLAUDE.md> [CLAUDE.md ...]
# Output: header + one row per file
#   path  total_lines  effective_lines  imports  has_agents_md_import  has_agents_md_sibling
#     - effective_lines: total minus HTML-comment-only lines (the cost Claude actually pays)
#     - imports: count of @path imports
#     - has_agents_md_sibling: whether AGENTS.md exists next to CLAUDE.md
set -euo pipefail
printf 'path\ttotal_lines\teffective_lines\timports\thas_agents_md_import\thas_agents_md_sibling\n'

for f in "$@"; do
  if [ ! -f "$f" ]; then
    printf '%s\t-\t-\t-\t-\t-\n' "$f"
    continue
  fi

  total_lines=$(wc -l < "$f" | tr -d ' ')
  # strip block-level HTML comments (zero-cost lines), then count
  effective_lines=$(awk '
    BEGIN { in_c = 0 }
    {
      line = $0
      while (1) {
        if (in_c) {
          p = index(line, "-->")
          if (p == 0) { line = ""; break }
          line = substr(line, p + 3); in_c = 0
        } else {
          p = index(line, "<!--")
          if (p == 0) break
          q = index(substr(line, p + 4), "-->")
          if (q == 0) { line = substr(line, 1, p - 1); in_c = 1; break }
          line = substr(line, 1, p - 1) substr(line, p + 4 + q + 2)
        }
      }
      if (line ~ /[^[:space:]]/) print line
    }
  ' "$f" | wc -l | tr -d ' ')
  effective_lines=${effective_lines:-0}

  imports=$(grep -cE '^\s*@[A-Za-z0-9_./~-]+' "$f" 2>/dev/null || true); imports=${imports:-0}
  has_agents_import=$(grep -qE '^\s*@AGENTS\.md\b' "$f" && echo yes || echo no)

  d=$(dirname "$f")
  has_agents_sibling=$([ -f "$d/AGENTS.md" ] && echo yes || echo no)

  printf '%s\t%d\t%d\t%d\t%s\t%s\n' \
    "$f" "$total_lines" "$effective_lines" "$imports" "$has_agents_import" "$has_agents_sibling"
done
