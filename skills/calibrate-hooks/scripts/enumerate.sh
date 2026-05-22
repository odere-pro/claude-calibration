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
  find "$PROJECT/.claude/hooks" -type f ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
    | while read -r f; do emit script "$f"; done
fi
if [ -d "$HOME/.claude/hooks" ]; then
  find "$HOME/.claude/hooks" -type f ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
    | while read -r f; do emit script-user "$f"; done
fi
# Plugin self: when PROJECT is itself a plugin, enumerate its shipped hooks/ — the `hooks.json` and
# any standalone scripts. Plugin-shipped hooks load for every user who enables the plugin, so they
# need to be in scope for the rubric (especially the `if`-field scoping and `exit 2` checks).
if [ -f "$PROJECT/.claude-plugin/plugin.json" ] && [ -d "$PROJECT/hooks" ]; then
  find "$PROJECT/hooks" -type f ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
    | while read -r f; do emit plugin-self "$f"; done
fi
