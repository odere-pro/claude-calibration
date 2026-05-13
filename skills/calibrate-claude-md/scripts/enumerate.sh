#!/usr/bin/env bash
# enumerate.sh — list every CLAUDE.md / CLAUDE.local.md across user and project (recursively).
# Usage: enumerate.sh [project-dir]
# Output: scope\tpath  (scopes: user, project, nested)
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

# user scope
[ -f "$HOME/CLAUDE.md" ] && emit user "$HOME/CLAUDE.md"
[ -f "$HOME/.claude/CLAUDE.md" ] && emit user "$HOME/.claude/CLAUDE.md"

# project root
[ -f "$PROJECT/CLAUDE.md" ] && emit project "$PROJECT/CLAUDE.md"
[ -f "$PROJECT/CLAUDE.local.md" ] && emit project "$PROJECT/CLAUDE.local.md"

# nested CLAUDE.md anywhere else in the project tree
if [ -d "$PROJECT" ]; then
  find "$PROJECT" \
    -name 'CLAUDE.md' \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path "$PROJECT/CLAUDE.md" \
    -print 2>/dev/null \
    | while read -r f; do emit nested "$f"; done
fi
