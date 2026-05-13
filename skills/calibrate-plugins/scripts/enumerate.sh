#!/usr/bin/env bash
# enumerate.sh — list installed plugins + marketplaces; if PROJECT_DIR is a plugin's own repo, also list its manifest.
# Usage: enumerate.sh [project-dir]
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

[ -f "$HOME/.claude/plugins/installed_plugins.json" ] && emit installed "$HOME/.claude/plugins/installed_plugins.json"
[ -f "$HOME/.claude/plugins/known_marketplaces.json" ] && emit marketplaces "$HOME/.claude/plugins/known_marketplaces.json"

# the cache (one entry per installed plugin payload)
if [ -d "$HOME/.claude/plugins/cache" ]; then
  find "$HOME/.claude/plugins/cache" -mindepth 3 -maxdepth 3 -type d -print 2>/dev/null \
    | while read -r d; do emit cache "$d"; done
fi

# is PROJECT itself a plugin? (manifest at .claude-plugin/plugin.json)
if [ -f "$PROJECT/.claude-plugin/plugin.json" ]; then
  emit self-manifest "$PROJECT/.claude-plugin/plugin.json"
  # `rules` is a valid plugin-root component too (path-scoped rules ship with the plugin).
  for sub in skills agents rules hooks .mcp.json .lsp.json monitors bin commands; do
    if [ -e "$PROJECT/$sub" ]; then emit self-component "$PROJECT/$sub"; fi
    if [ -e "$PROJECT/.claude-plugin/$sub" ]; then emit self-misplaced "$PROJECT/.claude-plugin/$sub"; fi
  done
fi
