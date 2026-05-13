#!/usr/bin/env bash
# lint.sh — check SKILL.md files against the calibrate-skills rubric.
# Usage: lint.sh <SKILL.md> [SKILL.md ...]
# Output: path\tsignature\tseverity\tdetail
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

NAME_MAX=64
DESC_MAX=1536
BODY_MAX=500

# Extract frontmatter region (between leading --- markers) to stdout.
frontmatter() {
  awk 'BEGIN{state=0} /^---[[:space:]]*$/{state++; if(state==2) exit; next} state==1{print}' "$1"
}

# Extract body (everything after the closing --- marker).
body() {
  awk 'BEGIN{state=0} /^---[[:space:]]*$/{state++; next} state>=2{print}' "$1"
}

# Field extraction from YAML frontmatter (best-effort; folded scalars handled crudely).
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

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -f "$f" ] || { emit "$f" "skill:not-found" HIGH "file does not exist"; continue; }

  fm=$(frontmatter "$f" 2>/dev/null || true)
  bd=$(body "$f" 2>/dev/null || true)

  name=$(field name "$f" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^["'\'']//; s/["'\'']$//')
  desc=$(field description "$f" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  when=$(field when_to_use "$f" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  dmi=$(printf '%s\n' "$fm" | grep -E '^disable-model-invocation:[[:space:]]*true' || true)
  allowed=$(printf '%s\n' "$fm" | awk '/^allowed-tools:/{sub(/^allowed-tools:[[:space:]]*/, ""); print; exit}')

  # missing fields
  if [ -z "$name" ]; then
    emit "$f" "skill:missing-name" HIGH "frontmatter 'name' missing or empty"
  fi
  if [ -z "$desc" ]; then
    emit "$f" "skill:missing-description" HIGH "frontmatter 'description' missing or empty"
  fi

  # name length
  if [ -n "$name" ]; then
    name_len=${#name}
    if [ "$name_len" -gt "$NAME_MAX" ]; then
      emit "$f" "skill:name-over-${NAME_MAX}" HIGH "name $name_len chars > $NAME_MAX (hard cap)"
    fi
  fi

  # description + when_to_use combined budget
  if [ -n "$desc" ] || [ -n "$when" ]; then
    combined_len=$(( ${#desc} + ${#when} ))
    if [ "$combined_len" -gt "$DESC_MAX" ]; then
      emit "$f" "skill:description-over-${DESC_MAX}" MEDIUM "description+when_to_use $combined_len chars > $DESC_MAX (routing budget)"
    fi
  fi

  # vague description
  if [ -n "$desc" ]; then
    desc_len=${#desc}
    if [ "$desc_len" -lt 80 ] \
       || ! printf '%s' "$desc" | grep -qiE '\b(use|when|after|before)\b'; then
      emit "$f" "skill:vague-description" MEDIUM "description lacks routing words (use/when/after/before) or is < 80 chars — Claude can't route on it"
    fi
  fi

  # body line count
  body_lines=$(printf '%s\n' "$bd" | grep -cE '[^[:space:]]' 2>/dev/null || true); body_lines=${body_lines:-0}
  if [ "$body_lines" -gt "$BODY_MAX" ]; then
    emit "$f" "skill:body-over-${BODY_MAX}" MEDIUM "body $body_lines effective lines > $BODY_MAX (move detail into reference.md)"
  fi

  # side-effecting verbs without disable-model-invocation: true
  if printf '%s\n' "$bd" | grep -qiE '\b(deploy|commit|push|publish|release|delete|post)\b'; then
    if [ -z "$dmi" ]; then
      emit "$f" "skill:side-effecting-no-dmi" HIGH "body uses side-effecting verbs but 'disable-model-invocation: true' is absent — Claude can auto-fire"
    fi
  fi

  # allowed-tools bare-form (Bash / Edit / Write without parens)
  if [ -n "$allowed" ]; then
    # tokenize by comma; check each token
    IFS=',' read -r -a tokens <<< "$allowed"
    for tok in "${tokens[@]}"; do
      t=$(printf '%s' "$tok" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
      case "$t" in
        Bash|Edit|Write)
          emit "$f" "skill:allowed-tools-broad" LOW "bare '$t' in allowed-tools — scope it (e.g. Bash(<cli> *), Edit(<glob>))"
          ;;
      esac
    done
  fi

  # CLI usage in body without a scoped Bash(<tool> *) allowed-tools entry
  body_clis=$(printf '%s\n' "$bd" | grep -oE '\b(gh|kubectl|aws|pnpm|gcloud|docker|terraform|helm)\b' | sort -u || true)
  if [ -n "$body_clis" ]; then
    for cli in $body_clis; do
      if ! printf '%s' "$allowed" | grep -qE "Bash\([[:space:]]*${cli}[[:space:]]"; then
        emit "$f" "skill:cli-not-wrapped" LOW "body shells out to '$cli' but allowed-tools has no scoped Bash($cli *) — 3→4-layer wrapper candidate"
      fi
    done
  fi

  # in-repo-only OK (anti-signature): no CLI usage, no side-effecting verbs
  if [ -z "$body_clis" ] \
     && ! printf '%s\n' "$bd" | grep -qiE '\b(deploy|commit|push|publish|release|delete|post)\b'; then
    emit "$f" "skill:in-repo-only-ok" INFO "skill is in-repo-only — correctly 3-layer; no promotion needed"
  fi
done
