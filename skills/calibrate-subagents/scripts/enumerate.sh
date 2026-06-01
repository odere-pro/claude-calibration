#!/usr/bin/env bash
# enumerate.sh — list every subagent .md across user / project / plugin-self / plugin-cache.
# Usage: enumerate.sh [project-dir]
# Output: scope\tpath  (scopes: user, project, plugin-self)
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

# Shared plugin allow/block filter (best-effort; pass-through stubs if unreachable).
. "$(dirname "$0")/../../lib/plugin-filter.sh" 2>/dev/null || true
command -v cpf_in_scope >/dev/null 2>&1 || cpf_in_scope() { return 0; }
command -v cpf_extract_plugin_name >/dev/null 2>&1 || cpf_extract_plugin_name() { printf '%s' "${1##*/}"; }

# user scope
if [ -d "$HOME/.claude/agents" ]; then
  find "$HOME/.claude/agents" -maxdepth 2 -name '*.md' ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
    | while read -r f; do emit user "$f"; done
fi

# project scope
if [ -d "$PROJECT/.claude/agents" ]; then
  find "$PROJECT/.claude/agents" -maxdepth 2 -name '*.md' ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
    | while read -r f; do emit project "$f"; done
fi

# plugin-self: PROJECT is itself a plugin — a local-scope plugin, gated by name + local scope.
if [ -f "$PROJECT/.claude-plugin/plugin.json" ] && [ -d "$PROJECT/agents" ]; then
  self_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PROJECT/.claude-plugin/plugin.json" 2>/dev/null | head -1)"
  [ -n "$self_name" ] || self_name="$(basename "$PROJECT")"
  if cpf_in_scope "$self_name" local; then
    find "$PROJECT/agents" -maxdepth 2 -name '*.md' ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
      | while read -r f; do emit plugin-self "$f"; done
  fi
fi

# plugin-cache: best-effort, depth-limited; name-gated (global scope)
if [ -d "$HOME/.claude/plugins/cache" ]; then
  find "$HOME/.claude/plugins/cache" -maxdepth 6 -path '*/agents/*.md' ! -name 'CLAUDE.md' ! -name 'README.md' -print 2>/dev/null \
    | while read -r f; do
        cpf_in_scope "$(cpf_extract_plugin_name "$f")" global || continue
        emit plugin-self "$f"
      done
fi
