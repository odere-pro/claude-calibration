#!/usr/bin/env bash
# lint.sh — check subagent .md files against the calibrate-subagents rubric.
# Usage: lint.sh <agent.md> [agent.md ...]
# Output: path\tsignature\tseverity\tdetail
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

BODY_MAX=200

frontmatter() {
  awk 'BEGIN{state=0} /^---[[:space:]]*$/{state++; if(state==2) exit; next} state==1{print}' "$1"
}
body() {
  awk 'BEGIN{state=0} /^---[[:space:]]*$/{state++; next} state>=2{print}' "$1"
}
field() {
  awk -v key="$1" '
    BEGIN{state=0; found=0}
    /^---[[:space:]]*$/{state++; if(state==2) exit; next}
    state==1 {
      if (found) {
        if (/^[A-Za-z_][A-Za-z0-9_-]*:/) exit
        sub(/^[[:space:]]+/, " "); printf "%s", $0; next
      }
      if (match($0, "^"key":[[:space:]]*")) {
        rest=substr($0, RLENGTH+1)
        if (rest ~ /^[>|]/) { found=1; next }
        printf "%s", rest
        exit
      }
    }
  ' "$2" 2>/dev/null
}
field_present() {
  awk -v key="$1" '
    BEGIN{state=0; found=0}
    /^---[[:space:]]*$/{state++; if(state==2) exit; next}
    state==1 && $0 ~ "^"key":" {found=1; exit}
    END{print (found ? "yes" : "no")}
  ' "$2" 2>/dev/null
}

# Determine if the agent file lives under a plugin (walk up looking for .claude-plugin/plugin.json).
in_plugin() {
  local dir
  dir=$(cd "$(dirname "$1")" 2>/dev/null && pwd || echo "")
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -f "$dir/.claude-plugin/plugin.json" ]; then
      # Only flag if this agent is in the plugin's shipped agents/ (root level), not in
      # .claude/agents/ (the plugin author's own dev setup).
      case "$1" in
        "$dir"/agents/*) echo yes; return ;;
      esac
    fi
    dir=$(dirname "$dir")
  done
  echo no
}

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -f "$f" ] || { emit "$f" "subagent:not-found" HIGH "file does not exist"; continue; }

  name=$(field name "$f" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^["'\'']//; s/["'\'']$//')
  desc=$(field description "$f" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  tools_present=$(field_present tools "$f")
  model_present=$(field_present model "$f")
  hooks_present=$(field_present hooks "$f")
  mcps_present=$(field_present mcpServers "$f")
  perm_present=$(field_present permissionMode "$f")

  if [ -z "$name" ]; then
    emit "$f" "subagent:missing-name" HIGH "frontmatter 'name' missing or empty"
  fi
  if [ -z "$desc" ]; then
    emit "$f" "subagent:missing-description" HIGH "frontmatter 'description' missing or empty"
  fi

  if [ "$tools_present" = "no" ]; then
    emit "$f" "subagent:missing-tools" HIGH "frontmatter 'tools:' absent — agent inherits EVERY tool including MCP servers"
  fi

  if [ "$model_present" = "no" ]; then
    emit "$f" "subagent:default-inherit-model" MEDIUM "frontmatter 'model:' absent — defaults to 'inherit' (silently uses parent's model, often Opus)"
  fi

  # vague description
  if [ -n "$desc" ]; then
    desc_len=${#desc}
    if [ "$desc_len" -lt 80 ] \
       || ! printf '%s' "$desc" | grep -qiE '\b(use|when|after|before)\b'; then
      emit "$f" "subagent:vague-description" MEDIUM "description lacks routing words (use/when/after/before) or is < 80 chars — Claude can't route on it"
    fi
  fi

  # body length
  bd=$(body "$f" 2>/dev/null || true)
  body_lines=$(printf '%s\n' "$bd" | grep -cE '[^[:space:]]' 2>/dev/null || true); body_lines=${body_lines:-0}
  if [ "$body_lines" -gt "$BODY_MAX" ]; then
    emit "$f" "subagent:body-over-${BODY_MAX}" MEDIUM "body $body_lines effective lines > $BODY_MAX (routing detail belongs in description)"
  fi

  # plugin-ignored frontmatter
  if [ "$(in_plugin "$f")" = "yes" ]; then
    if [ "$hooks_present" = "yes" ] || [ "$mcps_present" = "yes" ] || [ "$perm_present" = "yes" ]; then
      emit "$f" "subagent:plugin-ignored-frontmatter" LOW "plugin-shipped agent has hooks/mcpServers/permissionMode frontmatter — silently ignored"
    fi
  fi
done
