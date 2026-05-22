#!/usr/bin/env bash
# plugin-dev-guard.sh — enforce plugin-dev "Don't" directives.
# PreToolUse hook: fires on Edit/Write within this project.
# Rules enforced:
#   1. rules/ files written without paths: frontmatter are blocked (exit 2).
#   2. hooks/ files written with curl/wget remote fetches are blocked (exit 2).
# Zero-cost when not applicable (early exit).
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); i=d.get('tool_input',{}); print(i.get('file_path', i.get('path','')))" 2>/dev/null || echo "")

# Only act on Write and Edit tool calls
case "$TOOL" in
  Write|Edit|MultiEdit) ;;
  *) echo "$INPUT"; exit 0 ;;
esac

# Scope: only enforce against files inside THIS project (CLAUDE_PROJECT_DIR).
# User-scope edits (~/.claude/rules/*, etc.) are not this hook's business.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
case "$FILE_PATH" in
  "$PROJECT_DIR"/*) ;;
  *) echo "$INPUT"; exit 0 ;;
esac

# Resolve effective content: Write supplies `content`; Edit supplies `new_string` but we need
# the file's actual full content (or the result of applying the edit). For frontmatter checks
# the existing file's frontmatter is what matters, so read from disk for Edit/MultiEdit.
get_effective_content() {
  local path="$1"
  local content
  content=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); i=d.get('tool_input',{}); print(i.get('content',''))" 2>/dev/null || echo "")
  if [ -n "$content" ]; then
    printf '%s' "$content"
  elif [ -f "$path" ]; then
    cat "$path"
  fi
}

# Guard 1: rules/ files must have paths: frontmatter.
# Exempt CLAUDE.md — a per-directory briefing, not a path-scoped rule (matches gate G6).
case "$FILE_PATH" in
  */rules/CLAUDE.md)
    ;;
  */rules/*.md)
    CONTENT=$(get_effective_content "$FILE_PATH")
    if printf '%s' "$CONTENT" | grep -qE '^---'; then
      if ! printf '%s' "$CONTENT" | awk '/^---/{c++} c==1 && /^paths:/{found=1} END{exit !found}'; then
        echo "[plugin-dev-guard] BLOCKED: rules/ file lacks paths: frontmatter. Every rule under rules/ MUST have paths: (see .claude/rules/plugin-dev.md)." >&2
        exit 2
      fi
    else
      echo "[plugin-dev-guard] BLOCKED: rules/ file lacks YAML frontmatter (and therefore paths:). Every rule under rules/ MUST have paths: frontmatter." >&2
      exit 2
    fi
    ;;
esac

# Guard 2: hooks/ files must not curl/wget remote payloads
case "$FILE_PATH" in
  */hooks/*.sh|*/hooks/*.js)
    CONTENT=$(get_effective_content "$FILE_PATH")
    if printf '%s' "$CONTENT" | grep -qE '\b(curl|wget)\b.*(https?://)'; then
      echo "[plugin-dev-guard] BLOCKED: hook script contains curl/wget with a remote URL. Vendor scripts locally instead of fetching at fire-time (see .claude/rules/plugin-dev.md)." >&2
      exit 2
    fi
    ;;
esac

echo "$INPUT"
exit 0
