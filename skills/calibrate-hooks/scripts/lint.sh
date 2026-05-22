#!/usr/bin/env bash
# lint.sh — check settings.json `hooks` blocks and hook scripts against the calibrate-hooks rubric.
# Usage: lint.sh <settings.json | hook-script.sh> [path …]
# Output: path\tsignature\tseverity\tdetail
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

have_jq() { command -v jq >/dev/null 2>&1; }
have_py() { command -v python3 >/dev/null 2>&1; }

# Hot events whose hooks fire on every relevant tool call.
HOT_EVENTS_RE='^(PreToolUse|PostToolUse|UserPromptSubmit)$'
# Known system tools we accept in hook commands without flagging not-locally-sourced.
KNOWN_TOOLS_RE='^(bash|sh|env|node|python3?|jq|yq|grep|awk|sed|cat|echo|printf|test|true|false|cd|pwd|ls|find|xargs|rg|fd|head|tail|sort|uniq|wc|tr|cut|tee|mkdir|cp|mv|ln|chmod|touch|date)$'

# We pass-through gracefully if neither jq nor python3 is available.
parse_settings() {
  local f="$1"
  if have_py; then
    python3 - "$f" <<'PY' 2>/dev/null || return 1
import json, sys
d = json.load(open(sys.argv[1]))
hooks = d.get("hooks") or {}
if not isinstance(hooks, dict): sys.exit(0)
for event, entries in hooks.items():
    if not isinstance(entries, list): continue
    for entry in entries:
        if not isinstance(entry, dict): continue
        matcher = entry.get("matcher", "")
        for h in (entry.get("hooks") or []):
            if not isinstance(h, dict): continue
            cmd = h.get("command", "")
            # one row per hook command: event \t matcher \t command
            print(f"{event}\t{matcher}\t{cmd}")
PY
  elif have_jq; then
    jq -r '
      (.hooks // {}) as $h
      | $h | to_entries[]
      | .key as $event
      | .value[]?
      | (.matcher // "") as $m
      | (.hooks // [])[]?
      | [$event, $m, (.command // "")] | @tsv
    ' "$f" 2>/dev/null || return 1
  else
    return 2
  fi
}

# collect all (event, matcher, command) tuples across the inputs so duplicate-across-layers
# can fire when multiple settings paths are passed.
TMP_ALL=$(mktemp 2>/dev/null || mktemp -t hooks-lint)
trap 'rm -f "$TMP_ALL"' EXIT

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -e "$f" ] || { emit "$f" "hook:not-found" HIGH "path does not exist"; continue; }

  base=$(basename "$f")
  case "$base" in
    *.json)
      # validate JSON first
      if have_py; then
        if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
          emit "$f" "hook:invalid-json" HIGH "$base does not parse as JSON"
          continue
        fi
      elif have_jq; then
        if ! jq -e . "$f" >/dev/null 2>&1; then
          emit "$f" "hook:invalid-json" HIGH "$base does not parse as JSON"
          continue
        fi
      fi

      rows=$(parse_settings "$f" || true)
      [ -z "${rows:-}" ] && continue

      while IFS=$'\t' read -r event matcher cmd; do
        [ -z "$event" ] && continue
        # record for cross-file dedupe
        printf '%s\t%s\t%s\t%s\n' "$f" "$event" "$matcher" "$cmd" >>"$TMP_ALL"

        # matcher-bare-star on hot events
        if echo "$event" | grep -qE "$HOT_EVENTS_RE"; then
          if [ -z "$matcher" ] || [ "$matcher" = "*" ]; then
            emit "$f" "hook:matcher-bare-star" MEDIUM \
              "$event hook uses bare '*'/empty matcher — narrow to specific tools (e.g. Edit|Write|MultiEdit) plus a path pattern"
          fi
        fi

        # heavy work on hot events
        if echo "$event" | grep -qE '^(PreToolUse|PostToolUse)$'; then
          if echo "$cmd" | grep -qE '\b(build|test|tsc|webpack|compile|vitest|jest|pytest|cargo build|cargo test|go build|go test)\b'; then
            emit "$f" "hook:heavy-on-pretooluse-heuristic" MEDIUM \
              "$event hook command looks heavy (matches build/test/tsc/webpack/compile) — move to Stop or a manual command"
          fi
        fi

        # remote-untrusted in the inline command
        if echo "$cmd" | grep -qE '(\b(curl|wget)\b[^|]*https?://)|(\bnpx[[:space:]]+(--[[:alnum:]-]+[[:space:]]+)*[@a-zA-Z0-9_./-]+@)|(\bnpx[[:space:]]+(--package[[:space:]]+|-p[[:space:]]+))'; then
          emit "$f" "hook:remote-untrusted" HIGH \
            "hook command fetches a remote payload (curl/wget URL or npx remote package) — vendor the script under \${CLAUDE_PROJECT_DIR} or \${CLAUDE_PLUGIN_ROOT}"
        fi

        # not-locally-sourced: the first token isn't ${CLAUDE_PROJECT_DIR}/, ${CLAUDE_PLUGIN_ROOT}/,
        # or a known system tool.
        first=$(echo "$cmd" | awk '{print $1}')
        case "$first" in
          \$\{CLAUDE_PROJECT_DIR\}*|\$\{CLAUDE_PLUGIN_ROOT\}*|/*|"") : ;;
          *)
            if ! echo "$first" | grep -qE "$KNOWN_TOOLS_RE"; then
              emit "$f" "hook:not-locally-sourced" LOW \
                "hook command starts with '$first' — prefer \${CLAUDE_PROJECT_DIR}/... or \${CLAUDE_PLUGIN_ROOT}/... over relying on system PATH"
            fi
            ;;
        esac
      done <<<"$rows"
      ;;

    *)
      # treat as hook script
      # exit-1-non-blocking: an `exit 1` close to an echo of BLOCKED/error
      if grep -nE '^[[:space:]]*exit[[:space:]]+1([[:space:]]|$)' "$f" >/dev/null 2>&1; then
        # look for a BLOCKED/error echo within ~10 lines above
        if awk '
          /echo.*BLOCKED|echo.*[Ee]rror|printf.*BLOCKED|printf.*[Ee]rror/ { last_block=NR }
          /^[[:space:]]*exit[[:space:]]+1([[:space:]]|$)/ {
            if (last_block && NR - last_block <= 10) { print "yes"; exit }
          }
        ' "$f" | grep -q yes; then
          emit "$f" "hook:exit-1-non-blocking" HIGH \
            "uses 'exit 1' after a BLOCKED/error echo — exit 1 is a non-blocking warning; use 'exit 2' to actually block the tool call"
        fi
      fi

      # remote-untrusted inside a script body
      if grep -nE '(\b(curl|wget)\b[^|]*https?://)|(\bnpx[[:space:]]+(--package[[:space:]]+|-p[[:space:]]+|[@a-zA-Z0-9_./-]+@))' "$f" >/dev/null 2>&1; then
        emit "$f" "hook:remote-untrusted" HIGH \
          "hook script fetches a remote payload (curl/wget URL or npx remote package) — vendor it locally"
      fi

      # not-locally-sourced: scan for non-pathy, non-system-tool command invocations.
      # Heuristic: lines that look like `command-with-no-slash ...` where command isn't in
      # the known-tools list and isn't a shell construct (if/then/fi/for/while/case/etc.).
      while IFS= read -r line; do
        # strip leading whitespace and comments
        case "$line" in
          \#*|"") continue ;;
        esac
        first=$(echo "$line" | awk '{print $1}')
        case "$first" in
          \#*|\$\{CLAUDE_PROJECT_DIR\}*|\$\{CLAUDE_PLUGIN_ROOT\}*|/*|./*|\$*|\"*|*\)|";;"|"") continue ;;  # comment / path / var / quoted / case-label / terminator
          if|then|fi|else|elif|for|while|do|done|case|esac|return|exit|break|continue|shift|unset|eval|local|export|set|trap|read|declare|function|\[|\[\[|\}|\{) continue ;;
          *=*) continue ;;  # variable assignment
        esac
        if ! echo "$first" | grep -qE "$KNOWN_TOOLS_RE"; then
          emit "$f" "hook:not-locally-sourced" LOW \
            "script calls '$first' from PATH — prefer \${CLAUDE_PROJECT_DIR}/... or \${CLAUDE_PLUGIN_ROOT}/..."
          break
        fi
      done < <(grep -vE '^[[:space:]]*$' "$f" 2>/dev/null || true)
      ;;
  esac
done

# duplicate-across-layers: same (event, matcher, command) seen in 2+ files
if [ -s "$TMP_ALL" ]; then
  awk -F'\t' '
    {
      key = $2 SUBSEP $3 SUBSEP $4
      ev[key] = $2
      mt[key] = $3
      files[key] = (files[key] ? files[key] "," $1 : $1)
      n[key]++
    }
    END {
      for (k in n) {
        if (n[k] >= 2) {
          c = split(files[k], parts, ",")
          for (i = 1; i <= c; i++) {
            printf "%s\thook:duplicate-across-layers\tLOW\tsame (event=%s, matcher=%s, command=...) is defined in %d layer(s); deduplicate\n", parts[i], ev[k], mt[k], n[k]
          }
        }
      }
    }
  ' "$TMP_ALL"
fi
