#!/usr/bin/env bash
# lint.sh — check settings.json files against the calibrate-settings rubric.
# Usage: lint.sh <settings.json> [settings.json ...]
# Output: path\tsignature\tseverity\tdetail
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

ENV_LIMIT=10

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -f "$f" ] || { emit "$f" "settings:not-found" HIGH "file does not exist"; continue; }

  # --- JSON validity gate ---
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" >/dev/null 2>&1; then
    err=$(python3 -c "import json,sys
try:
  json.load(open(sys.argv[1]))
except Exception as e:
  print(str(e))" "$f" 2>&1 | head -1)
    emit "$f" "settings:invalid-json" HIGH "JSON parse error: ${err}"
    continue
  fi

  # --- dangerously-skip-permissions (any layer, any reference) ---
  if grep -F "dangerously-skip-permissions" "$f" >/dev/null 2>&1; then
    emit "$f" "settings:dangerously-skip-permissions" CRITICAL "reference to --dangerously-skip-permissions found — remove it"
  fi

  # --- is this a committed (non-.local) file? ---
  is_local=no
  case "$f" in
    *.local.json) is_local=yes ;;
  esac

  # --- secret-in-committed (skip .local files) ---
  if [ "$is_local" = "no" ]; then
    if grep -nEi '(\b(api[_-]?key|secret|token|password|access[_-]?key)\s*[:=]\s*[^[:space:]]{8,})|(sk-[A-Za-z0-9]{16,})|(\bAKIA[0-9A-Z]{16}\b)|(\bghp_[A-Za-z0-9]{20,})' "$f" >/dev/null; then
      emit "$f" "settings:secret-in-committed" CRITICAL "candidate committed secret matched — move to .local.json or use \${ENV_VAR}, then rotate"
    fi
  fi

  # --- structural checks via python (permissions, model, env) ---
  python3 - "$f" "$is_local" "$ENV_LIMIT" <<'PY'
import json, sys
path = sys.argv[1]
is_local = sys.argv[2] == "yes"
env_limit = int(sys.argv[3])

def emit(sig, sev, detail):
    print(f"{path}\t{sig}\t{sev}\t{detail}")

try:
    with open(path) as fh:
        d = json.load(fh)
except Exception:
    sys.exit(0)  # invalid-json already handled

# permissions.allow checks
perms = d.get("permissions") or {}
allow = perms.get("allow")
if not allow:
    emit("settings:permissions-empty", "LOW",
         "no permissions.allow entries — every tool call prompts for manual approval")
else:
    if isinstance(allow, list):
        bad = []
        for entry in allow:
            if not isinstance(entry, str):
                continue
            e = entry.strip()
            # blanket / destructive shapes
            if e in ("Bash(*)", "Bash(* )", "Bash( *)"):
                bad.append(entry)
            elif e.lower().startswith("bash(rm ") or e.lower().startswith("bash(rm -rf"):
                bad.append(entry)
            elif e.lower().startswith("bash(sudo "):
                bad.append(entry)
        if bad:
            emit("settings:permissions-blanket-destructive", "HIGH",
                 f"destructive/blanket entries: {', '.join(bad)}")

# model pin in committed
if not is_local and "model" in d and d.get("model"):
    emit("settings:model-pinned-in-committed", "LOW",
         f"model pinned to {d['model']!r} in committed settings — move to .local.json")

# env bloat
env = d.get("env") or {}
if isinstance(env, dict) and len(env) > env_limit:
    emit("settings:env-bloated", "LOW",
         f"{len(env)} env entries > {env_limit} — move per-machine values to .local.json")
PY
done
