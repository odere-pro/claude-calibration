#!/usr/bin/env bash
# enumerate.sh — list every subagent .md across user, project, and installed plugins.
# Usage: enumerate.sh [project-dir]   (default: cwd)
# Output (TSV, no header):
#   scope\tpath
set -euo pipefail
PROJECT="${1:-$(pwd)}"

emit() { printf '%s\t%s\n' "$1" "$2"; }

if [ -d "$HOME/.claude/agents" ]; then
  find "$HOME/.claude/agents" -maxdepth 1 -name '*.md' -print 2>/dev/null \
    | while read -r f; do emit user "$f"; done
fi

if [ -d "$PROJECT/.claude/agents" ]; then
  find "$PROJECT/.claude/agents" -maxdepth 1 -name '*.md' -print 2>/dev/null \
    | while read -r f; do emit project "$f"; done
fi

if [ -d "$HOME/.claude/plugins/cache" ]; then
  find "$HOME/.claude/plugins/cache" -path '*/agents/*.md' -print 2>/dev/null \
    | while read -r f; do emit plugin "$f"; done
fi
