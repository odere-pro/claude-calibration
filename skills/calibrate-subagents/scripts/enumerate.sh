#!/usr/bin/env bash
# enumerate.sh — list every subagent .md across user / project / plugin-self / plugin-cache.
# Usage: enumerate.sh [project-dir]
# Output: scope\tpath  (scopes: user, project, plugin-self)
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

# user scope
if [ -d "$HOME/.claude/agents" ]; then
  find "$HOME/.claude/agents" -maxdepth 2 -name '*.md' -print 2>/dev/null \
    | while read -r f; do emit user "$f"; done
fi

# project scope
if [ -d "$PROJECT/.claude/agents" ]; then
  find "$PROJECT/.claude/agents" -maxdepth 2 -name '*.md' -print 2>/dev/null \
    | while read -r f; do emit project "$f"; done
fi

# plugin-self
if [ -f "$PROJECT/.claude-plugin/plugin.json" ] && [ -d "$PROJECT/agents" ]; then
  find "$PROJECT/agents" -maxdepth 2 -name '*.md' -print 2>/dev/null \
    | while read -r f; do emit plugin-self "$f"; done
fi

# plugin-cache: best-effort, depth-limited
if [ -d "$HOME/.claude/plugins/cache" ]; then
  find "$HOME/.claude/plugins/cache" -maxdepth 6 -path '*/agents/*.md' -print 2>/dev/null \
    | while read -r f; do emit plugin-self "$f"; done
fi
