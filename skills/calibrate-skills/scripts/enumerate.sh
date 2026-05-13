#!/usr/bin/env bash
# enumerate.sh — list every SKILL.md across user / project / plugin-self / plugin-cache.
# Usage: enumerate.sh [project-dir]
# Output: scope\tpath  (scopes: user, project, plugin-self)
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

# user scope
if [ -d "$HOME/.claude/skills" ]; then
  find "$HOME/.claude/skills" -name 'SKILL.md' -print 2>/dev/null \
    | while read -r f; do emit user "$f"; done
fi

# project scope
if [ -d "$PROJECT/.claude/skills" ]; then
  find "$PROJECT/.claude/skills" -name 'SKILL.md' -print 2>/dev/null \
    | while read -r f; do emit project "$f"; done
fi

# plugin-self: when PROJECT is itself a plugin (has .claude-plugin/plugin.json), enumerate its
# shipped skills/ too.
if [ -f "$PROJECT/.claude-plugin/plugin.json" ] && [ -d "$PROJECT/skills" ]; then
  find "$PROJECT/skills" -name 'SKILL.md' -print 2>/dev/null \
    | while read -r f; do emit plugin-self "$f"; done
fi

# plugin-cache: best-effort, depth-limited so we don't hammer the FS
if [ -d "$HOME/.claude/plugins/cache" ]; then
  find "$HOME/.claude/plugins/cache" -maxdepth 6 -name 'SKILL.md' -print 2>/dev/null \
    | while read -r f; do emit plugin-self "$f"; done
fi
