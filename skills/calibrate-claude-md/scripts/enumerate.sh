#!/usr/bin/env bash
# enumerate.sh — list every CLAUDE.md / CLAUDE.local.md across user, project (walking up + nested), managed.
# Usage: enumerate.sh [project-dir]   (default: cwd)
# Output (TSV, no header):
#   scope\tpath
#   scope ∈ {user, project, project-local, project-claude-dir, nested, managed}
set -euo pipefail
PROJECT="${1:-$(pwd)}"

emit() { printf '%s\t%s\n' "$1" "$2"; }

# user
[ -f "$HOME/.claude/CLAUDE.md" ] && emit user "$HOME/.claude/CLAUDE.md"

# project + ancestors (walk up from PROJECT to filesystem root; NOT past it)
dir="$(cd "$PROJECT" && pwd)"
while [ "$dir" != "/" ] && [ -n "$dir" ]; do
  [ -f "$dir/CLAUDE.md" ] && emit project "$dir/CLAUDE.md"
  [ -f "$dir/CLAUDE.local.md" ] && emit project-local "$dir/CLAUDE.local.md"
  [ -f "$dir/.claude/CLAUDE.md" ] && emit project-claude-dir "$dir/.claude/CLAUDE.md"
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

# nested CLAUDE.md below the project (load-on-demand)
if [ -d "$PROJECT" ]; then
  find "$PROJECT" -name CLAUDE.md -not -path "$PROJECT/CLAUDE.md" -print 2>/dev/null \
    | while read -r f; do emit nested "$f"; done
fi

# managed (best-effort; usually not readable, but report if present)
case "$(uname -s)" in
  Darwin) [ -f "/Library/Application Support/ClaudeCode/CLAUDE.md" ] && emit managed "/Library/Application Support/ClaudeCode/CLAUDE.md" ;;
  Linux)  [ -f "/etc/claude-code/CLAUDE.md" ] && emit managed "/etc/claude-code/CLAUDE.md" ;;
esac
