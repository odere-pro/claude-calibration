#!/usr/bin/env bash
# lint.sh — check SKILL.md files against the calibrate-skills rubric.
# Usage: lint.sh <SKILL.md> [SKILL.md ...]
# Output (TSV, no header; multiple rows per file possible):
#   path\tsignature\tseverity\tdetail
# Signatures match reference.md's "Pattern signatures" table.
set -euo pipefail

DESC_LIMIT=1536
BODY_LIMIT=500
NAME_LIMIT=64

emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

# (mirrors measure.sh's fold_value)
fold_value() {
  local key="$1"
  awk -v key="$key" '
    BEGIN { inv = 0; out = "" }
    {
      if (inv) {
        if (match($0, /^[A-Za-z_][A-Za-z0-9_-]*:/)) { inv = 0 }
        else { line = $0; sub(/^[ \t]+/, "", line); out = (out=="") ? line : out " " line }
      }
      if (!inv && match($0, "^" key ":[ \t]*")) {
        inv = 1
        line = $0
        sub("^" key ":[ \t]*>?-?\\|?[ \t]*", "", line)
        if (line != "") out = (out=="") ? line : out " " line
      }
    }
    END { gsub(/^[ \t]+|[ \t]+$/, "", out); print out }
  '
}

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  if [ ! -f "$f" ]; then
    emit "$f" "skill:not-found" HIGH "file does not exist"
    continue
  fi

  body_lines=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==2{print}' "$f" | wc -l | tr -d ' ')
  fm=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==1' "$f")
  desc=$(printf '%s\n' "$fm" | fold_value description)
  wtu=$( printf '%s\n' "$fm" | fold_value when_to_use)
  combined=$(( ${#desc} + ${#wtu} ))
  name=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d ' "')
  has_dmi=$(printf '%s\n' "$fm" | grep -qE '^disable-model-invocation:[[:space:]]*true' && echo yes || echo no)
  allowed_tools=$(printf '%s\n' "$fm" | grep -E '^allowed-tools:' | head -1 || true)

  # ---- structural ----
  if [ -z "$name" ]; then
    emit "$f" "skill:missing-name" HIGH "no name in frontmatter"
  elif [ "${#name}" -gt $NAME_LIMIT ]; then
    emit "$f" "skill:name-over-${NAME_LIMIT}" HIGH "name length ${#name} > $NAME_LIMIT"
  fi

  if [ -z "$desc" ]; then
    emit "$f" "skill:missing-description" HIGH "no description in frontmatter"
  elif [ "$combined" -gt $DESC_LIMIT ]; then
    emit "$f" "skill:description-over-${DESC_LIMIT}" MEDIUM "description+when_to_use=$combined > $DESC_LIMIT"
  fi

  if [ "$body_lines" -gt $BODY_LIMIT ]; then
    emit "$f" "skill:body-over-${BODY_LIMIT}" MEDIUM "body $body_lines lines > $BODY_LIMIT"
  fi

  # ---- semantic ----
  # side-effecting body without dmi
  if [ "$has_dmi" = "no" ]; then
    if grep -qiE '\b(deploy|commit|push|publish|release|delete|drop |destroy|send slack|post to|webhook|rollback)\b' "$f"; then
      emit "$f" "skill:side-effecting-no-dmi" HIGH "side-effecting verbs in body but no disable-model-invocation: true"
    fi
  fi

  # vague description (lacks any "trigger"-shaped keyword: verbs / nouns specific to a task)
  if [ -n "$desc" ] && [ "${#desc}" -lt 30 ]; then
    emit "$f" "skill:vague-description" MEDIUM "description very short (${#desc} chars) — likely lacks routing keywords"
  fi

  # broad allowed-tools (bare Bash / Edit / Write without scoping)
  if [ -n "$allowed_tools" ]; then
    if printf '%s' "$allowed_tools" | grep -qE '\bBash\b' && \
       ! printf '%s' "$allowed_tools" | grep -q 'Bash('; then
      emit "$f" "skill:allowed-tools-broad" LOW "allowed-tools includes bare Bash (consider Bash(<cmd> *) scoping)"
    fi
  fi

  # 4-layer signal: body shells out to a known CLI (3-vs-4-layer call)
  if grep -qE '\b(gh|kubectl|aws|pnpm|npm|yarn|gcloud|docker|terraform|helm)\b' "$f"; then
    if [ -z "$allowed_tools" ] || ! printf '%s' "$allowed_tools" | grep -qE 'Bash\([^)]+ \*\)'; then
      emit "$f" "skill:cli-not-wrapped" LOW "body references a known CLI without a scoped Bash(<tool> *) allowed-tools — consider templates/cli-wrapper.tmpl"
    fi
  fi
done
