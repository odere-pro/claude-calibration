#!/usr/bin/env bash
# lint.sh — check hooks blocks (in settings.json layers) + hook scripts against the rubric.
# Usage: lint.sh <settings.json|hook-script> [...]
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -f "$f" ] || { emit "$f" "hook:not-found" HIGH "file does not exist"; continue; }

  # Settings file with hooks
  if printf '%s' "$f" | grep -qE 'settings(\.local)?\.json$'; then
    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
      emit "$f" "hook:invalid-json" HIGH "settings file is not valid JSON"
      continue
    fi
    # Walk the hooks block; emit findings via python.
    python3 - "$f" <<'PY' || true
import json, re, sys
f = sys.argv[1]
d = json.load(open(f))
hooks = d.get("hooks") or {}
HOT = {"PreToolUse","PostToolUse","UserPromptSubmit"}
HEAVY_KW = re.compile(r'\b(build|test|compile|tsc|webpack|vite build|next build|cargo build|go build)\b', re.I)
REMOTE_KW = re.compile(r'(\bcurl\s+|\bwget\s+|\bnpx\s+(?!@?[\w-]+\b))')
for event, groups in hooks.items():
    if not isinstance(groups, list): continue
    for g in groups:
        matcher = g.get("matcher", "")
        for h in (g.get("hooks") or []):
            cmd = (h.get("command") or "")
            if event in HOT and matcher in ("", "*"):
                print(f"{f}\thook:matcher-bare-star\tMEDIUM\tevent={event} matcher='{matcher}' on a hot event — narrow it (Edit|Write, Bash, mcp__server__.*)")
            if REMOTE_KW.search(cmd) and "://" in cmd:
                print(f"{f}\thook:remote-untrusted\tHIGH\tevent={event} command fetches/runs remote ({cmd[:80]}…) — use a project-owned script")
            if event in {"PreToolUse","PostToolUse"} and HEAVY_KW.search(cmd):
                print(f"{f}\thook:heavy-on-pretooluse-heuristic\tMEDIUM\tevent={event} command looks heavy ({cmd[:80]}…) — move to Stop")
PY
  else
    # Hook script
    if grep -nE 'echo[[:space:]]+["\047]?(\[Hook\][[:space:]]+)?(BLOCKED|ERROR|REJECT)' "$f" >/dev/null 2>&1; then
      if grep -qE 'exit[[:space:]]+1\b' "$f"; then
        emit "$f" "hook:exit-1-non-blocking" HIGH "script appears to enforce (BLOCKED/ERROR echo) but uses exit 1 (which does NOT block) — use exit 2"
      fi
    fi
    if grep -qE '\b(curl|wget|npx)\s+(https?://|@?[a-z0-9-]+/)' "$f"; then
      emit "$f" "hook:remote-untrusted" HIGH "script fetches/runs remote — use project-owned tooling"
    fi
  fi
done
