#!/usr/bin/env bash
# lint.sh — cross-cutting checks. Takes a project dir; estimates standing context cost; checks
# gitignore + must-rule-with-no-hook rolled up.
# Usage: lint.sh [project-dir]   (default: cwd)
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

# always-on diagnostic ask
emit "$PROJECT" "general:diagnostics-ask" INFO "ask the user to paste /doctor + /context all + /skills (press t) + /mcp output for live numbers"

# gitignore for personal/local files
gi="$PROJECT/.gitignore"
if [ -f "$gi" ]; then
  for needle in 'CLAUDE.local.md' '.claude/settings.local.json' '.claude/calibration/'; do
    if ! grep -q "$needle" "$gi" 2>/dev/null; then
      emit "$gi" "general:no-gitignore-for-claude-local" LOW "missing entry: $needle"
    fi
  done
else
  emit "$PROJECT" "general:no-gitignore-for-claude-local" LOW "no .gitignore at project root — CLAUDE.local.md / .claude/settings.local.json / .claude/calibration/ may end up committed"
fi

# rolled-up must-rule-with-no-hook (across CLAUDE.md + rules)
must_total=0
for f in "$PROJECT/CLAUDE.md" "$PROJECT/CLAUDE.local.md" "$PROJECT/.claude/CLAUDE.md"; do
  [ -f "$f" ] || continue
  c=$(grep -ciE '^\s*[-*]\s*(always|never|must|don['"'"']t|do not)\b' "$f" 2>/dev/null || true); c=${c:-0}
  must_total=$(( must_total + c ))
done
if [ -d "$PROJECT/.claude/rules" ]; then
  c=$(grep -rciE '^\s*[-*]\s*(always|never|must|don['"'"']t|do not)\b' "$PROJECT/.claude/rules" 2>/dev/null \
       | awk -F: '{s+=$2} END{print s+0}')
  must_total=$(( must_total + c ))
fi
has_hooks="no"
for f in "$PROJECT/.claude/settings.json" "$PROJECT/.claude/settings.local.json"; do
  grep -q '"hooks"' "$f" 2>/dev/null && has_hooks="yes"
done
[ -d "$PROJECT/.claude/hooks" ] && has_hooks="yes"
if [ "$must_total" -ge 5 ] && [ "$has_hooks" = "no" ]; then
  emit "$PROJECT" "general:must-rule-with-no-hook" MEDIUM "$must_total 'always/never/must' rules across CLAUDE.md+rules but no hooks block — for enforce-every-time, use a hook"
fi

# nested CLAUDE.md count (rough conflict-risk indicator)
nested=$(find "$PROJECT" -name CLAUDE.md -not -path "$PROJECT/CLAUDE.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "${nested:-0}" -ge 3 ]; then
  emit "$PROJECT" "general:nested-claude-md-conflict" LOW "$nested nested CLAUDE.md files below project root — review for contradictions; consider claudeMdExcludes"
fi

# crude standing-cost estimate (chars across always-on inputs, ÷ 4 ≈ tokens)
total_chars=0
for f in "$PROJECT/CLAUDE.md" "$PROJECT/CLAUDE.local.md" "$PROJECT/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"; do
  [ -f "$f" ] && total_chars=$(( total_chars + $(wc -c < "$f" 2>/dev/null) ))
done
for d in "$PROJECT/.claude/rules" "$HOME/.claude/rules"; do
  [ -d "$d" ] || continue
  # only unconditional (no `paths:` frontmatter)
  while IFS= read -r f; do
    if ! awk 'BEGIN{state=0} /^---$/{state++; next} state==1 && /^paths:/{found=1} END{exit !found}' "$f"; then
      total_chars=$(( total_chars + $(wc -c < "$f" 2>/dev/null) ))
    fi
  done < <(find "$d" -name '*.md' -print 2>/dev/null)
done
# approximate: chars ÷ 4 = tokens
approx_tokens=$(( total_chars / 4 ))
if [ "$approx_tokens" -gt 5000 ]; then
  emit "$PROJECT" "general:context-budget-overflow" MEDIUM "estimated standing cost ~${approx_tokens} tokens (CLAUDE.md + unconditional rules) — paste /context all for the authoritative number"
fi
