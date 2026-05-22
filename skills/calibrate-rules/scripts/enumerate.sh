#!/usr/bin/env bash
# enumerate.sh — list every .claude/rules/*.md across user and project (recursively).
# Usage: enumerate.sh [project-dir]
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

if [ -d "$HOME/.claude/rules" ]; then
  find "$HOME/.claude/rules" -name '*.md' ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
    | while read -r f; do emit user "$f"; done
fi
if [ -d "$PROJECT/.claude/rules" ]; then
  find "$PROJECT/.claude/rules" -name '*.md' ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
    | while read -r f; do emit project "$f"; done
fi
# Plugin self: when PROJECT is itself a plugin (has .claude-plugin/plugin.json), enumerate its
# shipped rules/ too — plugin-shipped rules without `paths:` load for every user who enables the
# plugin, so they need to be in scope for the rubric.
if [ -f "$PROJECT/.claude-plugin/plugin.json" ] && [ -d "$PROJECT/rules" ]; then
  find "$PROJECT/rules" -name '*.md' ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
    | while read -r f; do emit plugin-self "$f"; done
fi
