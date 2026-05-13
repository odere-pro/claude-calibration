#!/usr/bin/env bash
# lint.sh — cross-cutting synthesizer over a project dir.
# Usage: lint.sh <project-dir>
# Output: path\tsignature\tseverity\tdetail   (always exits 0)
#
# Detail-format contract (parsed by /calibrate cost):
#   general:context-budget-overflow   → detail contains "~Ntokens" substring
#   general:nested-claude-md-conflict → detail leads with an integer
#   general:must-rule-with-no-hook    → detail leads with an integer
#   general:diagnostics-ask           → fixed reminder text (always emitted)
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

PROJECT="${1:-$(pwd)}"
BUDGET_TOKENS=5000

# --- ALWAYS emit diagnostics-ask first ---
emit "$PROJECT" "general:diagnostics-ask" INFO \
  "paste /doctor /context all /skills (press t) /mcp for exact numbers"

# --- context-budget-overflow ---
# Estimate: CLAUDE.md lines + sum of effective lines in unconditional rules (no paths: frontmatter).
# ~5 chars per line / 4 chars per token  →  multiplier = 5/4 = 1.25 tokens per line.
total_lines=0
if [ -f "$PROJECT/CLAUDE.md" ]; then
  cm=$(wc -l <"$PROJECT/CLAUDE.md" 2>/dev/null | tr -d ' ' || echo 0)
  cm=${cm:-0}
  total_lines=$((total_lines + cm))
fi

# Walk .claude/rules/**/*.md; count only files WITHOUT `paths:` in their frontmatter.
if [ -d "$PROJECT/.claude/rules" ]; then
  while IFS= read -r rule; do
    has_paths=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==1 && /^paths:/{print "yes"; exit}' "$rule")
    has_paths=${has_paths:-no}
    if [ "$has_paths" = "no" ]; then
      n=$(grep -cE '[^[:space:]]' "$rule" 2>/dev/null || echo 0)
      n=${n:-0}
      total_lines=$((total_lines + n))
    fi
  done < <(find "$PROJECT/.claude/rules" -name '*.md' -print 2>/dev/null)
fi

# Convert lines → estimated tokens. Use integer math: tokens ≈ lines * 5 / 4.
tokens=$(( total_lines * 5 / 4 ))
if [ "$tokens" -gt "$BUDGET_TOKENS" ]; then
  emit "$PROJECT" "general:context-budget-overflow" MEDIUM \
    "CLAUDE.md + unconditional rules ≈ ~${tokens}tokens (> ${BUDGET_TOKENS}tokens budget); trim CLAUDE.md and add paths: to rules"
fi

# --- nested-claude-md-conflict ---
# Count CLAUDE.md files BELOW the project root (exclude the root file itself).
nested_count=0
if [ -d "$PROJECT" ]; then
  nested_count=$(find "$PROJECT" -mindepth 2 -name 'CLAUDE.md' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | wc -l | tr -d ' ')
  nested_count=${nested_count:-0}
fi
if [ "$nested_count" -ge 3 ]; then
  emit "$PROJECT" "general:nested-claude-md-conflict" LOW \
    "$nested_count nested CLAUDE.md files under project root — consolidate or accept the layered design"
fi

# --- no-gitignore-for-claude-local ---
gi="$PROJECT/.gitignore"
if [ -f "$gi" ]; then
  missing=()
  grep -qE '(^|/)CLAUDE\.local\.md([[:space:]]|$)|(^|/)\*\*?/?CLAUDE\.local\.md' "$gi" 2>/dev/null \
    || missing+=("CLAUDE.local.md")
  grep -qE 'settings\.local\.json' "$gi" 2>/dev/null \
    || missing+=(".claude/settings.local.json")
  grep -qE '\.claude/calibration' "$gi" 2>/dev/null \
    || missing+=(".claude/calibration/")
  if [ "${#missing[@]}" -gt 0 ]; then
    emit "$PROJECT" "general:no-gitignore-for-claude-local" LOW \
      ".gitignore missing entries: ${missing[*]}"
  fi
fi

# --- must-rule-with-no-hook ---
# Count lines that look like enforcement claims (start with - or * bullet, contain always/never/must)
# across CLAUDE.md and .claude/rules/**/*.md. Then check whether any settings layer has a hooks block.
must_lines=0
rule_files_touched=0
scan_must() {
  local f="$1"
  if [ ! -f "$f" ]; then return 0; fi
  local n=0
  n=$(grep -cE '^[[:space:]]*[-*]?[[:space:]]*\b(always|never|must)\b' "$f" 2>/dev/null | head -1 | tr -dc '0-9' || true)
  if [ -z "$n" ]; then n=0; fi
  if [ "$n" -gt 0 ]; then
    must_lines=$((must_lines + n))
    rule_files_touched=$((rule_files_touched + 1))
  fi
  return 0
}

scan_must "$PROJECT/CLAUDE.md"
if [ -d "$PROJECT/.claude/rules" ]; then
  while IFS= read -r rule; do
    scan_must "$rule"
  done < <(find "$PROJECT/.claude/rules" -name '*.md' -print 2>/dev/null)
fi

# Does any settings layer contain a hooks block?
has_hooks=no
for s in \
  "$PROJECT/.claude/settings.json" \
  "$PROJECT/.claude/settings.local.json" \
  "$HOME/.claude/settings.json" \
  "$HOME/.claude/settings.local.json"; do
  if [ -f "$s" ] && grep -q '"hooks"' "$s" 2>/dev/null; then
    has_hooks=yes
    break
  fi
done

if [ "$must_lines" -gt 0 ] && [ "$has_hooks" = "no" ]; then
  # Adjust the count of rule files mentioned (CLAUDE.md is one of the touched files; subtract it)
  rules_only=$((rule_files_touched > 0 ? rule_files_touched - 1 : 0))
  emit "$PROJECT" "general:must-rule-with-no-hook" MEDIUM \
    "$must_lines always/never/must lines across CLAUDE.md and $rules_only rules — no enforcement hook configured"
fi

exit 0
