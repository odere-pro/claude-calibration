#!/usr/bin/env bash
# enumerate.sh — list every SKILL.md across user, project, and installed plugins.
# Usage: enumerate.sh [project-dir]   (default: cwd)
# Output (TSV, no header):
#   scope\tpath
#   scope ∈ {user, user-legacy, project, project-legacy, plugin}
set -euo pipefail
PROJECT="${1:-$(pwd)}"

emit() { printf '%s\t%s\n' "$1" "$2"; }

# user (~/.claude/skills/<name>/SKILL.md)
if [ -d "$HOME/.claude/skills" ]; then
  find "$HOME/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print 2>/dev/null \
    | while read -r f; do emit user "$f"; done
fi
# user legacy (~/.claude/commands/*.md)
if [ -d "$HOME/.claude/commands" ]; then
  find "$HOME/.claude/commands" -maxdepth 1 -name '*.md' -print 2>/dev/null \
    | while read -r f; do emit user-legacy "$f"; done
fi

# project (<project>/.claude/skills/<name>/SKILL.md)
if [ -d "$PROJECT/.claude/skills" ]; then
  find "$PROJECT/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print 2>/dev/null \
    | while read -r f; do emit project "$f"; done
fi
# project legacy (<project>/.claude/commands/*.md)
if [ -d "$PROJECT/.claude/commands" ]; then
  find "$PROJECT/.claude/commands" -maxdepth 1 -name '*.md' -print 2>/dev/null \
    | while read -r f; do emit project-legacy "$f"; done
fi

# installed plugins (best-effort — paths under cache/<marketplace>/<plugin>/skills/<name>/SKILL.md)
if [ -d "$HOME/.claude/plugins/cache" ]; then
  find "$HOME/.claude/plugins/cache" -path '*/skills/*/SKILL.md' -print 2>/dev/null \
    | while read -r f; do emit plugin "$f"; done
fi
