#!/usr/bin/env bash
# measure.sh — print TSV measurements for one or more SKILL.md files.
# Usage: measure.sh <SKILL.md> [SKILL.md ...]
# Output (header + one row per file):
#   path  body_lines  desc_chars  combined_desc_chars  has_dmi  has_when_to_use  name_len
set -euo pipefail
printf 'path\tbody_lines\tdesc_chars\tcombined_desc_chars\thas_dmi\thas_when_to_use\tname_len\n'

# Fold a YAML scalar value across continuation lines until the next top-level key.
# Reads frontmatter on stdin; arg $1 is the key name (e.g. "description").
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
  if [ ! -f "$f" ]; then
    printf '%s\t-\t-\t-\t-\t-\t-\n' "$f"
    continue
  fi

  body_lines=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==2{print}' "$f" | wc -l | tr -d ' ')
  fm=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==1' "$f")

  desc=$(printf '%s\n' "$fm" | fold_value description)
  wtu=$(printf  '%s\n' "$fm" | fold_value when_to_use)
  desc_chars=${#desc}
  wtu_chars=${#wtu}
  combined=$(( desc_chars + wtu_chars ))

  has_dmi=$(printf '%s\n' "$fm" | grep -qE '^disable-model-invocation:[[:space:]]*true' && echo yes || echo no)
  has_wtu=$( [ "$wtu_chars" -gt 0 ] && echo yes || echo no )
  name=$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d ' "')
  name_len=${#name}

  printf '%s\t%d\t%d\t%d\t%s\t%s\t%d\n' \
    "$f" "$body_lines" "$desc_chars" "$combined" "$has_dmi" "$has_wtu" "$name_len"
done
