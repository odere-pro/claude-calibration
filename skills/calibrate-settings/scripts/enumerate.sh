#!/usr/bin/env bash
# enumerate.sh — list every settings.json layer across user + project + plugin-self.
# Usage: enumerate.sh [project-dir]
# Output: scope\tpath  (scopes: user, user-local, project, project-local, plugin-self)
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

[ -f "$HOME/.claude/settings.json"        ] && emit user        "$HOME/.claude/settings.json"
[ -f "$HOME/.claude/settings.local.json"  ] && emit user-local  "$HOME/.claude/settings.local.json"
[ -f "$PROJECT/.claude/settings.json"       ] && emit project       "$PROJECT/.claude/settings.json"
[ -f "$PROJECT/.claude/settings.local.json" ] && emit project-local "$PROJECT/.claude/settings.local.json"

# Plugin-self: when PROJECT is itself a plugin (has .claude-plugin/plugin.json), also list its
# own .claude/settings.json if present — the plugin author's dev-time settings live here.
if [ -f "$PROJECT/.claude-plugin/plugin.json" ] && [ -f "$PROJECT/.claude/settings.json" ]; then
  # already emitted above as project; this branch is kept for parity with calibrate-rules
  :
fi
