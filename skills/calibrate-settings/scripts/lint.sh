#!/usr/bin/env bash
# lint.sh — check settings.json layers against the calibrate-settings rubric.
# Usage: lint.sh <settings.json> [settings.json ...]
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

is_committed() {
  case "$1" in
    *.local.json|*.claude.json) return 1 ;;   # personal layers
    *) return 0 ;;
  esac
}

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -f "$f" ] || { emit "$f" "settings:not-found" HIGH "file does not exist"; continue; }

  # JSON validity
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
    emit "$f" "settings:invalid-json" HIGH "file is not valid JSON"
    continue
  fi

  # secrets in committed files
  if is_committed "$f"; then
    if python3 -c '
import json, re, sys
with open(sys.argv[1]) as fh: d = json.load(fh)
def walk(o):
    if isinstance(o, dict):
        for k,v in o.items(): yield from walk(v)
    elif isinstance(o, list):
        for v in o: yield from walk(v)
    elif isinstance(o, str): yield o
pats = [r"sk-[A-Za-z0-9]{16,}", r"\bAKIA[0-9A-Z]{16}\b", r"\bghp_[A-Za-z0-9]{20,}",
        r"\bxox[bp]-[A-Za-z0-9-]{20,}",
        r"^[A-Za-z0-9+/]{32,}={0,2}$"]
for s in walk(d):
    for p in pats:
        if re.search(p, s):
            print("HIT"); sys.exit(0)
sys.exit(1)
    ' "$f" 2>/dev/null; then
      emit "$f" "settings:secret-in-committed" CRITICAL "candidate secret in a committed settings file — move to settings.local.json and rotate"
    fi
  fi

  # dangerously-skip-permissions
  if grep -q 'dangerously-skip-permissions' "$f"; then
    emit "$f" "settings:dangerously-skip-permissions" CRITICAL "settings reference dangerously-skip-permissions — remove and use a real permissions allowlist"
  fi

  # blanket destructive permissions
  if python3 -c '
import json, re, sys
d = json.load(open(sys.argv[1]))
allow = (d.get("permissions") or {}).get("allow") or []
bad = [a for a in allow if isinstance(a,str) and re.match(r"^Bash\(\*\)|^Bash\(rm |^Bash\(sudo |^Bash\(curl ", a)]
sys.exit(0 if bad else 1)
  ' "$f" 2>/dev/null; then
    emit "$f" "settings:permissions-blanket-destructive" HIGH "permissions.allow contains a broadly destructive entry (Bash(*), rm, sudo, raw curl) — narrow it"
  fi

  # model pinned in committed
  if is_committed "$f" && python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if "model" in d else 1)
  ' "$f" 2>/dev/null; then
    emit "$f" "settings:model-pinned-in-committed" LOW "model: pinned in a committed settings file — consider availableModels to constrain instead, and route per task"
  fi

  # env bloat
  env_count=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get("env") or {}))' "$f" 2>/dev/null || echo 0)
  if [ "${env_count:-0}" -gt 10 ]; then
    emit "$f" "settings:env-bloated" LOW "env has $env_count entries (target ≲ 10) — prune to what's genuinely session-global"
  fi

  # empty permissions allow
  empty=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); a=(d.get("permissions") or {}).get("allow"); print(0 if a else 1)' "$f" 2>/dev/null || echo 1)
  if [ "$empty" = "1" ] && is_committed "$f"; then
    emit "$f" "settings:permissions-empty" LOW "no permissions.allow — every prompt is approved manually; let /fewer-permission-prompts draft a list"
  fi
done
