#!/usr/bin/env bash
# enumerate.sh — list installed plugins + marketplaces; if PROJECT_DIR is a plugin's own repo, also list its manifest.
# Usage: enumerate.sh [project-dir]
# Honours CALIBRATION_PLUGIN_FILTER (allow/block list + scope) — see ../../lib/plugin-filter.sh.
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

# Shared plugin allow/block filter (best-effort; pass-through stubs if unreachable so
# an isolated bundle run still enumerates everything).
. "$(dirname "$0")/../../lib/plugin-filter.sh" 2>/dev/null || true
command -v cpf_in_scope >/dev/null 2>&1 || cpf_in_scope() { return 0; }
command -v cpf_scope_allowed >/dev/null 2>&1 || cpf_scope_allowed() { return 0; }
command -v cpf_extract_plugin_name >/dev/null 2>&1 || cpf_extract_plugin_name() { printf '%s' "${1##*/}"; }

# global state files — gated by scope only (not plugin-specific)
[ -f "$HOME/.claude/plugins/installed_plugins.json" ] && cpf_scope_allowed global && emit installed "$HOME/.claude/plugins/installed_plugins.json"
[ -f "$HOME/.claude/plugins/known_marketplaces.json" ] && cpf_scope_allowed global && emit marketplaces "$HOME/.claude/plugins/known_marketplaces.json"

# the cache (one entry per installed plugin payload) — gated by name + global scope
if [ -d "$HOME/.claude/plugins/cache" ]; then
  find "$HOME/.claude/plugins/cache" -mindepth 3 -maxdepth 3 -type d -print 2>/dev/null \
    | while read -r d; do
        cpf_in_scope "$(cpf_extract_plugin_name "$d")" global || continue
        emit cache "$d"
      done
fi

# is PROJECT itself a plugin? (manifest at .claude-plugin/plugin.json) — a local-scope plugin
if [ -f "$PROJECT/.claude-plugin/plugin.json" ]; then
  self_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PROJECT/.claude-plugin/plugin.json" 2>/dev/null | head -1)"
  [ -n "$self_name" ] || self_name="$(basename "$PROJECT")"
  if cpf_in_scope "$self_name" local; then
    emit self-manifest "$PROJECT/.claude-plugin/plugin.json"
    # `rules` is a valid plugin-root component too (path-scoped rules ship with the plugin).
    for sub in skills agents rules hooks .mcp.json .lsp.json monitors bin commands; do
      if [ -e "$PROJECT/$sub" ]; then emit self-component "$PROJECT/$sub"; fi
      if [ -e "$PROJECT/.claude-plugin/$sub" ]; then emit self-misplaced "$PROJECT/.claude-plugin/$sub"; fi
    done
  fi
fi
