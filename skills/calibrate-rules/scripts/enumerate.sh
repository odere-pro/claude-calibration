#!/usr/bin/env bash
# enumerate.sh — list every .claude/rules/*.md across user and project (recursively).
# Usage: enumerate.sh [project-dir]
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

if [ -d "$HOME/.claude/rules" ]; then
  find "$HOME/.claude/rules" -name '*.md' -print 2>/dev/null \
    | while read -r f; do emit user "$f"; done
fi
if [ -d "$PROJECT/.claude/rules" ]; then
  find "$PROJECT/.claude/rules" -name '*.md' -print 2>/dev/null \
    | while read -r f; do emit project "$f"; done
fi
