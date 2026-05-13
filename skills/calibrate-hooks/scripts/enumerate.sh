#!/usr/bin/env bash
# enumerate.sh — list every settings layer that defines a `hooks` block, plus standalone scripts.
# Usage: enumerate.sh [project-dir]
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

for f in \
  "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json" \
  "$PROJECT/.claude/settings.json" "$PROJECT/.claude/settings.local.json"; do
  if [ -f "$f" ] && grep -q '"hooks"' "$f"; then emit settings "$f"; fi
done

if [ -d "$PROJECT/.claude/hooks" ]; then
  find "$PROJECT/.claude/hooks" -type f -print 2>/dev/null \
    | while read -r f; do emit script "$f"; done
fi
if [ -d "$HOME/.claude/hooks" ]; then
  find "$HOME/.claude/hooks" -type f -print 2>/dev/null \
    | while read -r f; do emit script-user "$f"; done
fi
