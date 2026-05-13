#!/usr/bin/env bash
# lint.sh — check CLAUDE.md / CLAUDE.local.md against the calibrate-claude-md rubric.
# Usage: lint.sh <CLAUDE.md> [CLAUDE.md ...]
# Output (TSV, no header):
#   path\tsignature\tseverity\tdetail
set -euo pipefail

OVER_200=200
OVER_400=400
IMPORT_DEPTH_LIMIT=5

emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

# Strip block-level HTML comments to get effective content.
strip_comments() {
  awk '
    BEGIN { in_c = 0 }
    {
      line = $0
      while (1) {
        if (in_c) {
          p = index(line, "-->")
          if (p == 0) { line = ""; break }
          line = substr(line, p + 3); in_c = 0
        } else {
          p = index(line, "<!--")
          if (p == 0) break
          q = index(substr(line, p + 4), "-->")
          if (q == 0) { line = substr(line, 1, p - 1); in_c = 1; break }
          line = substr(line, 1, p - 1) substr(line, p + 4 + q + 2)
        }
      }
      print line
    }
  ' "$1"
}

# Heuristic vague-rule patterns (low-precision; user reviews).
# Whole-line-ish phrases that look like bullets without specifics.
VAGUE_PATTERNS='\b(test (your|the) changes|format (the )?code( properly)?|be careful|use good judgement|write good code|follow best practices|keep things clean|stay organi[sz]ed)\b'

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  if [ ! -f "$f" ]; then
    emit "$f" "claude-md:not-found" HIGH "file does not exist"
    continue
  fi

  # ---- secrets (CRITICAL) ----
  # patterns: KEY/TOKEN/PASSWORD/SECRET assignments, sk-... openai-style, AKIA aws-style,
  # ghp_/github_pat_, slack xoxb-, generic api[_-]key=
  if grep -nEi '(\b(api[_-]?key|secret|token|password|access[_-]?key)\s*[:=]\s*[^[:space:]]{8,})|(sk-[A-Za-z0-9]{16,})|(\bAKIA[0-9A-Z]{16}\b)|(\bghp_[A-Za-z0-9]{20,})|(\bgithub_pat_[A-Za-z0-9_]{20,})|(\bxox[bp]-[A-Za-z0-9-]{20,})' "$f" >/dev/null; then
    emit "$f" "claude-md:secret-leak" CRITICAL "candidate committed secret matched — verify and rotate; use .env.example or a secrets manager"
  fi

  # ---- length ----
  # Use effective line count (HTML comments stripped).
  effective=$(strip_comments "$f" | grep -cE '[^[:space:]]' 2>/dev/null || true); effective=${effective:-0}
  if [ "$effective" -gt $OVER_400 ]; then
    emit "$f" "claude-md:over-${OVER_400}" HIGH "effective $effective lines > $OVER_400"
  elif [ "$effective" -gt $OVER_200 ]; then
    emit "$f" "claude-md:over-${OVER_200}" MEDIUM "effective $effective lines > $OVER_200 (move bulky content to .claude/rules/<topic>.md with paths:)"
  fi

  # ---- imports ----
  imports=$(grep -cE '^\s*@[A-Za-z0-9_./~-]+' "$f" 2>/dev/null || true); imports=${imports:-0}
  if [ "$imports" -gt $IMPORT_DEPTH_LIMIT ]; then
    emit "$f" "claude-md:imports-too-deep" HIGH "$imports @-imports > $IMPORT_DEPTH_LIMIT (hard cap)"
  fi

  # ---- AGENTS.md import ----
  d=$(dirname "$f")
  if [ -f "$d/AGENTS.md" ]; then
    if ! grep -qE '^\s*@AGENTS\.md\b' "$f"; then
      # Symlink form is also acceptable (Linux/macOS): CLAUDE.md → AGENTS.md.
      if [ ! -L "$f" ] || [ "$(readlink "$f" 2>/dev/null || true)" != "AGENTS.md" ]; then
        emit "$f" "claude-md:no-agents-md-import" LOW "AGENTS.md exists in $d but no @AGENTS.md import (or AGENTS.md symlink) in this CLAUDE.md"
      fi
    fi
  fi

  # ---- vague rules ----
  if grep -qiE "$VAGUE_PATTERNS" "$f"; then
    matches=$(grep -ciE "$VAGUE_PATTERNS" "$f" 2>/dev/null || true); matches=${matches:-0}
    emit "$f" "claude-md:vague-rules" MEDIUM "$matches vague-rule line(s) matched (e.g. 'test your changes', 'format code properly') — replace with concrete commands or delete"
  fi

  # ---- README restatement (heuristic: lots of project-overview prose vs. concrete instructions) ----
  if grep -qiE '^#\s*(About|Overview|What is|Description)\b' "$f" && [ "$effective" -gt $OVER_200 ]; then
    emit "$f" "claude-md:restated-readme" LOW "looks like README-style overview is present alongside Claude instructions — link to README instead"
  fi

  # ---- must-rule-with-no-hook (heuristic: 'always|never|must|don't' bullets, no hook config sibling) ----
  must_count=$(grep -ciE '^\s*[-*]\s*(always|never|must|don['"'"']t|do not)\b' "$f" 2>/dev/null || true); must_count=${must_count:-0}
  if [ "$must_count" -ge 3 ]; then
    proj_dir="$(dirname "$(dirname "$f")")"
    has_hooks="no"
    if grep -qE '"hooks"' "$proj_dir/.claude/settings.json" 2>/dev/null; then has_hooks="yes"; fi
    if grep -qE '"hooks"' "$proj_dir/.claude/settings.local.json" 2>/dev/null; then has_hooks="yes"; fi
    if [ -d "$proj_dir/.claude/hooks" ]; then has_hooks="yes"; fi
    if [ "$has_hooks" = "no" ]; then
      emit "$f" "claude-md:must-rule-with-no-hook" MEDIUM "$must_count must/never/always rules but no hooks block found in this project — CLAUDE.md is a request; for enforce-every-time rules use a hook"
    fi
  fi
done
