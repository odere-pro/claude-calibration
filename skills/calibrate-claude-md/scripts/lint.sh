#!/usr/bin/env bash
# lint.sh — check CLAUDE.md / CLAUDE.local.md / nested CLAUDE.md against the calibrate-claude-md rubric.
# Usage: lint.sh <path> [path ...]
# Output: path\tsignature\tseverity\tdetail
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }
OVER_200=200
OVER_400=400
MAX_IMPORT_HOPS=5

# follow @-imports up to MAX_IMPORT_HOPS; returns hop count (best-effort, no cycle guard beyond depth)
import_depth() {
  local file="$1" depth="${2:-0}" max=0 next d
  [ "$depth" -ge "$MAX_IMPORT_HOPS" ] && { echo "$depth"; return; }
  [ -f "$file" ] || { echo "$depth"; return; }
  local base
  base=$(dirname "$file")
  # match @path tokens at start of line or after whitespace; ignore code fences (best-effort)
  while IFS= read -r next; do
    [ -z "$next" ] && continue
    if [ "${next:0:1}" = "/" ] || [ "${next:0:1}" = "~" ]; then
      eval "next=$next"
    else
      next="$base/$next"
    fi
    d=$(import_depth "$next" $((depth + 1)))
    [ "$d" -gt "$max" ] && max="$d"
  done < <(grep -oE '(^|[[:space:]])@[A-Za-z0-9._/~-]+' "$file" 2>/dev/null | sed -E 's/^[[:space:]]*@//')
  if [ "$max" -gt 0 ]; then echo "$max"; else echo "$depth"; fi
}

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -f "$f" ] || { emit "$f" "claude-md:not-found" HIGH "file does not exist"; continue; }

  # secret check — same regex family as calibrate-rules/lint.sh
  if grep -nEi '(\b(api[_-]?key|secret|token|password|access[_-]?key)\s*[:=]\s*[^[:space:]]{8,})|(sk-[A-Za-z0-9]{16,})|(\bAKIA[0-9A-Z]{16}\b)|(\bghp_[A-Za-z0-9]{20,})' "$f" >/dev/null; then
    emit "$f" "claude-md:secret-leak" CRITICAL "candidate committed secret matched — verify and rotate"
  fi

  # effective line count
  effective=$(grep -cE '[^[:space:]]' "$f" 2>/dev/null || true); effective=${effective:-0}
  if [ "$effective" -gt "$OVER_400" ]; then
    emit "$f" "claude-md:over-${OVER_400}" HIGH "effective $effective lines > $OVER_400 (split into .claude/rules/<topic>.md)"
  elif [ "$effective" -gt "$OVER_200" ]; then
    emit "$f" "claude-md:over-${OVER_200}" MEDIUM "effective $effective lines > $OVER_200 (trim or move topic blocks out)"
  fi

  # vague rules: aspirational phrasing without specifics ("test your changes", "be careful", …).
  # Scan prose only — strip fenced code blocks and markdown headers (neither is a rule), then skip
  # lines that already carry a concrete anchor (backtick code, path, or command word). Bare modal
  # verbs (must/never/always/should) are NOT vague on their own — a precise prohibition is concrete —
  # so they no longer trigger this; that matches the rubric's definition in reference.md.
  vague_re='\b(test your changes|format code|be careful|best practices|make sure|do it properly|done properly|appropriately|as needed|as appropriate|good (practice|hygiene)|clean code|keep in mind|where possible|when possible|follow conventions|use common sense)\b'
  prose=$(awk 'BEGIN{fence=0} /^[[:space:]]*```/{fence=!fence; next} fence{next} /^[[:space:]]*#/{next} {print}' "$f")
  vague_hits=$(printf '%s\n' "$prose" | grep -niE "$vague_re" \
    | grep -vE '`[^`]+`|/[A-Za-z0-9_./-]+|\b(run|use|pnpm|npm|yarn|cargo|go|gh|kubectl|aws|docker|terraform|prettier|eslint|tsc|jest|vitest|pytest)\b' \
    | wc -l | tr -d ' ' || true)
  if [ "${vague_hits:-0}" -gt 0 ]; then
    emit "$f" "claude-md:vague-rules" MEDIUM "$vague_hits aspirational lines without specifics — rewrite as concrete verifiable rules"
  fi

  # must-rule with no enforcement hook (heuristic: file has must/always/never AND no .claude/hooks/ exists nearby)
  if grep -niE '^\s*[-*]?\s*(always |never |must )' "$f" >/dev/null; then
    dir=$(cd "$(dirname "$f")" 2>/dev/null && pwd || echo "")
    hooks_present=no
    while [ -n "$dir" ] && [ "$dir" != "/" ]; do
      if [ -f "$dir/.claude/settings.json" ] && grep -q '"hooks"' "$dir/.claude/settings.json" 2>/dev/null; then
        hooks_present=yes; break
      fi
      [ -d "$dir/.claude/hooks" ] && { hooks_present=yes; break; }
      dir=$(dirname "$dir")
    done
    if [ "$hooks_present" = "no" ]; then
      emit "$f" "claude-md:must-rule-with-no-hook" MEDIUM "body uses 'always/never/must' but no settings.json hooks block found nearby — wording is aspirational"
    fi
  fi

  # AGENTS.md exists in same dir, but no @AGENTS.md reference
  agents_md="$(dirname "$f")/AGENTS.md"
  if [ -f "$agents_md" ] && ! grep -qE '(^|[[:space:]])@AGENTS\.md' "$f"; then
    emit "$f" "claude-md:no-agents-md-import" LOW "sibling AGENTS.md exists but is not @-imported in CLAUDE.md"
  fi

  # import-chain depth
  depth=$(import_depth "$f" 0 || echo 0)
  if [ "${depth:-0}" -gt "$MAX_IMPORT_HOPS" ]; then
    emit "$f" "claude-md:imports-too-deep" HIGH "@-import chain $depth hops > $MAX_IMPORT_HOPS (flatten)"
  fi

  # restated-readme: body contains "# README" or large duplication candidate (cheap heuristic — header-only)
  if grep -qE '^#+\s*(README|Getting Started|Installation)\b' "$f"; then
    emit "$f" "claude-md:restated-readme" LOW "body has README-style headers — link to README.md instead of restating"
  fi

  # contradicts-nested: only firable when ≥2 CLAUDE.md exist at different levels and share a header line — best-effort here
  # (calibrator does a cross-file diff; this lint emits a stub when there's a parent CLAUDE.md)
  parent_dir=$(dirname "$(dirname "$f")")
  parent_md="$parent_dir/CLAUDE.md"
  # -ef compares device+inode, so a root-level file passed as a relative path ("CLAUDE.md") is
  # recognised as the same file as "./CLAUDE.md" — not diffed against itself (a false positive).
  if [ -f "$parent_md" ] && [ ! "$parent_md" -ef "$f" ]; then
    # Real markdown headers shared by both files. FNR==1 resets the fence flag per file so a shell
    # comment like '# do x' inside a ``` fence is not mistaken for a heading.
    shared=$(awk 'FNR==1{fence=0} /^[[:space:]]*```/{fence=!fence; next} fence{next} /^#+[[:space:]]/{print}' "$f" "$parent_md" 2>/dev/null | sort | uniq -d | head -1 || true)
    if [ -n "$shared" ]; then
      emit "$f" "claude-md:contradicts-nested" MEDIUM "shares header '$shared' with $parent_md — verify rules don't conflict"
    fi
  fi
done

# A clean file emits nothing; honour the always-exit-0 contract the evaluator/gates rely on
# (a trailing no-match grep above would otherwise leak rc=1).
exit 0
