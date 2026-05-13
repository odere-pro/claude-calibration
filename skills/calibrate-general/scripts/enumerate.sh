#!/usr/bin/env bash
# enumerate.sh — list every entry point that contributes to the cross-cutting / total-cost picture.
# Usage: enumerate.sh [project-dir]
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

# settings layers
for f in \
  "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json" \
  "$PROJECT/.claude/settings.json" "$PROJECT/.claude/settings.local.json"; do
  [ -f "$f" ] && emit settings "$f"
done

# claude-md (reuse the same shape as calibrate-claude-md)
[ -f "$HOME/.claude/CLAUDE.md" ] && emit claude-md "$HOME/.claude/CLAUDE.md"
dir="$(cd "$PROJECT" && pwd)"
while [ "$dir" != "/" ] && [ -n "$dir" ]; do
  [ -f "$dir/CLAUDE.md" ] && emit claude-md "$dir/CLAUDE.md"
  [ -f "$dir/CLAUDE.local.md" ] && emit claude-md "$dir/CLAUDE.local.md"
  [ -f "$dir/.claude/CLAUDE.md" ] && emit claude-md "$dir/.claude/CLAUDE.md"
  parent="$(dirname "$dir")"; [ "$parent" = "$dir" ] && break; dir="$parent"
done

# rules
for d in "$HOME/.claude/rules" "$PROJECT/.claude/rules"; do
  [ -d "$d" ] || continue
  find "$d" -name '*.md' -print 2>/dev/null | while read -r f; do emit rule "$f"; done
done

# skills
for d in "$HOME/.claude/skills" "$PROJECT/.claude/skills"; do
  [ -d "$d" ] || continue
  find "$d" -mindepth 2 -maxdepth 2 -name SKILL.md -print 2>/dev/null \
    | while read -r f; do emit skill "$f"; done
done

# agents
for d in "$HOME/.claude/agents" "$PROJECT/.claude/agents"; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -name '*.md' -print 2>/dev/null | while read -r f; do emit agent "$f"; done
done

# plugins
[ -f "$HOME/.claude/plugins/installed_plugins.json" ] && emit plugins "$HOME/.claude/plugins/installed_plugins.json"

# project gitignore
[ -f "$PROJECT/.gitignore" ] && emit gitignore "$PROJECT/.gitignore"
