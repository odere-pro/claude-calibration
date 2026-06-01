#!/usr/bin/env bash
# enumerate.sh — list every SKILL.md across user / project / plugin-self / plugin-cache.
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
# shipped skills/ too — a local-scope plugin, gated by name + local scope.
if [ -f "$PROJECT/.claude-plugin/plugin.json" ] && [ -d "$PROJECT/skills" ]; then
  self_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PROJECT/.claude-plugin/plugin.json" 2>/dev/null | head -1)"
  [ -n "$self_name" ] || self_name="$(basename "$PROJECT")"
  if cpf_in_scope "$self_name" local; then
    find "$PROJECT/skills" -name 'SKILL.md' -print 2>/dev/null \
      | while read -r f; do emit plugin-self "$f"; done
  fi
fi

# plugin-cache: best-effort, depth-limited so we don't hammer the FS; name-gated (global scope)
if [ -d "$HOME/.claude/plugins/cache" ]; then
  find "$HOME/.claude/plugins/cache" -maxdepth 6 -name 'SKILL.md' -print 2>/dev/null \
    | while read -r f; do
        cpf_in_scope "$(cpf_extract_plugin_name "$f")" global || continue
        emit plugin-self "$f"
      done
fi
