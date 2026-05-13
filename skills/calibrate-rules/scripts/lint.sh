#!/usr/bin/env bash
# lint.sh — check .claude/rules/*.md against the calibrate-rules rubric.
# Usage: lint.sh <rule.md> [rule.md ...]
# Output: path\tsignature\tseverity\tdetail
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }
OVER_200=200

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -f "$f" ] || { emit "$f" "rule:not-found" HIGH "file does not exist"; continue; }

  # secret check (same patterns as claude-md)
  if grep -nEi '(\b(api[_-]?key|secret|token|password|access[_-]?key)\s*[:=]\s*[^[:space:]]{8,})|(sk-[A-Za-z0-9]{16,})|(\bAKIA[0-9A-Z]{16}\b)|(\bghp_[A-Za-z0-9]{20,})' "$f" >/dev/null; then
    emit "$f" "rule:secret-leak" CRITICAL "candidate committed secret matched — verify and rotate"
  fi

  effective=$(grep -cE '[^[:space:]]' "$f" 2>/dev/null || true); effective=${effective:-0}
  if [ "$effective" -gt $OVER_200 ]; then
    emit "$f" "rule:over-${OVER_200}" MEDIUM "effective $effective lines > $OVER_200 (split or trim)"
  fi

  has_paths=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==1 && /^paths:/{print "yes"; exit}' "$f")
  has_paths=${has_paths:-no}

  base=$(basename "$f" .md)
  cites_lang=$(grep -qiE '\b(typescript|javascript|python|golang|rust|java|kotlin|swift|csharp|cpp|php)\b|\.(ts|tsx|js|jsx|py|go|rs|java|kt|swift|cs|cpp|php)\b' "$f" && echo yes || echo no)
  filename_lang=$(echo "$base" | grep -qiE '(typescript|javascript|python|golang|rust|java|kotlin|swift|csharp|cpp|php|frontend|backend|api|database|sql)' && echo yes || echo no)

  if [ "$has_paths" = "no" ] && { [ "$cites_lang" = "yes" ] || [ "$filename_lang" = "yes" ]; }; then
    emit "$f" "rule:no-paths-when-language-specific" MEDIUM "rule looks language- or area-specific (filename and/or body) but has no paths: frontmatter — costs context every request"
  fi

  # bad glob: paths: present but doesn't pass a basic shape check
  if [ "$has_paths" = "yes" ]; then
    paths_ok=$(awk 'BEGIN{state=0; in_paths=0; ok=1} /^---$/{state++; next} state==1 {
      if (/^paths:[[:space:]]*$/) { in_paths=1; next }
      if (/^paths:[[:space:]]*\[/) { in_paths=0; next }       # inline list
      if (in_paths) {
        if (/^[[:space:]]*-[[:space:]]*"[^"]+"[[:space:]]*$/) next
        if (/^[[:space:]]*-[[:space:]]*[^[:space:]"][^[:space:]]*[[:space:]]*$/) next
        if (/^[A-Za-z_][A-Za-z0-9_-]*:/) { in_paths=0 }       # next key
        else if (/[^[:space:]]/) { ok=0 }
      }
    } END { print (ok ? "yes" : "no") }' "$f")
    if [ "$paths_ok" = "no" ]; then
      emit "$f" "rule:bad-glob" HIGH "paths: frontmatter doesn't parse as a clean YAML list of glob strings"
    fi
  fi

  # workflow-shaped (numbered steps) → likely should be a skill
  numbered=$(grep -cE '^[[:space:]]*[0-9]+\.[[:space:]]' "$f" 2>/dev/null || true); numbered=${numbered:-0}
  if [ "$numbered" -ge 4 ]; then
    emit "$f" "rule:should-be-skill" LOW "$numbered numbered steps — looks like a workflow; consider a skill (loaded on demand) instead of a rule"
  fi
done
