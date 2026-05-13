#!/usr/bin/env bash
# lint.sh — check subagent .md files against the calibrate-subagents rubric.
# Usage: lint.sh <agent.md> [agent.md ...]
# Output (TSV, no header):
#   path\tsignature\tseverity\tdetail
set -euo pipefail

BODY_LIMIT=200

emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

# Detect "is this a plugin-shipped agent?" by path prefix.
is_plugin() {
  case "$1" in
    "$HOME/.claude/plugins/cache/"*) return 0 ;;
    *) return 1 ;;
  esac
}

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  if [ ! -f "$f" ]; then
    emit "$f" "subagent:not-found" HIGH "file does not exist"
    continue
  fi

  body_lines=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==2{print}' "$f" | wc -l | tr -d ' ')
  fm=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==1' "$f")

  name=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d ' "')
  desc_present=$(printf '%s\n' "$fm" | grep -qE '^description:'    && echo yes || echo no)
  has_tools=$(printf    '%s\n' "$fm" | grep -qE '^tools:'          && echo yes || echo no)
  has_model=$(printf    '%s\n' "$fm" | grep -qE '^model:'          && echo yes || echo no)

  # Crude description length (folded across continuations).
  desc=$(awk '
    BEGIN{inv=0; out=""}
    {
      if (inv) {
        if (match($0, /^[A-Za-z_][A-Za-z0-9_-]*:/)) { inv=0 }
        else { line=$0; sub(/^[ \t]+/, "", line); out = (out=="") ? line : out " " line }
      }
      if (!inv && match($0, /^description:[ \t]*/)) {
        inv=1
        line=$0; sub(/^description:[ \t]*>?-?\|?[ \t]*/, "", line)
        if (line != "") out = (out=="") ? line : out " " line
      }
    }
    END { gsub(/^[ \t]+|[ \t]+$/, "", out); print out }
  ' <<< "$fm")

  # ---- structural ----
  if [ -z "$name" ]; then
    emit "$f" "subagent:missing-name" HIGH "no name in frontmatter"
  fi
  if [ "$desc_present" = "no" ]; then
    emit "$f" "subagent:missing-description" HIGH "no description in frontmatter"
  elif [ "${#desc}" -lt 40 ]; then
    emit "$f" "subagent:vague-description" MEDIUM "description very short (${#desc} chars) — likely lacks routing cues"
  elif printf '%s' "$desc" | grep -qiE 'invoked only by|internal worker|not a general-purpose|(invoked|used) by /[a-z-]+'; then
    : # deliberately not auto-routed (internal worker for an entry-point command); skip cue check
  elif ! printf '%s' "$desc" | grep -qiE 'use\s+proactively|must\s+be\s+used|trigger|when\b'; then
    emit "$f" "subagent:vague-description" MEDIUM "description lacks routing cues like 'Use PROACTIVELY', 'MUST BE USED', or 'when …'"
  fi

  if [ "$has_tools" = "no" ]; then
    emit "$f" "subagent:missing-tools" HIGH "tools: omitted — subagent inherits ALL tools (incl. MCP); add an explicit minimal allowlist"
  fi

  if [ "$has_model" = "no" ]; then
    emit "$f" "subagent:default-inherit-model" MEDIUM "model: omitted (defaults to inherit); set explicit haiku/sonnet/opus"
  fi

  if [ "$body_lines" -gt $BODY_LIMIT ]; then
    emit "$f" "subagent:body-over-${BODY_LIMIT}" MEDIUM "body $body_lines lines > $BODY_LIMIT (consider splitting; preload a skill via skills:)"
  fi

  # plugin-shipped: flag silently-ignored frontmatter fields
  if is_plugin "$f"; then
    if printf '%s\n' "$fm" | grep -qE '^(hooks|mcpServers|permissionMode):'; then
      emit "$f" "subagent:plugin-ignored-frontmatter" LOW "plugin subagent has hooks/mcpServers/permissionMode (silently ignored for plugin agents)"
    fi
  fi
done
