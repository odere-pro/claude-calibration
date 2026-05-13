#!/usr/bin/env bash
# lint.sh — check .mcp.json / mcpServers blocks against the calibrate-mcp rubric.
# Usage: lint.sh <path …>      (.mcp.json or agent .md)
# Output: path\tsignature\tseverity\tdetail
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

OVER_BROAD=50

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -f "$f" ] || { emit "$f" "mcp:not-found" HIGH "file does not exist"; continue; }

  case "$f" in
    *.md)
      # agent file — no extra signatures here; calibrate-subagents owns the agent-side checks.
      # We accept the path so the bundle dispatch is uniform; do nothing.
      continue
      ;;
  esac

  # --- JSON validity gate ---
  if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" >/dev/null 2>&1; then
    err=$(python3 -c "import json,sys
try:
  json.load(open(sys.argv[1]))
except Exception as e:
  print(str(e))" "$f" 2>&1 | head -1)
    emit "$f" "mcp:invalid-json" HIGH "JSON parse error: ${err}"
    continue
  fi

  # --- secret-in-mcpjson — match a token shape that is NOT a ${...} placeholder ---
  # We grep over the raw file for token-shaped literals, then exclude lines whose value is a
  # placeholder. Patterns: Bearer <token>, sk-…, ghp_…, AKIA…, long key=value pairs.
  while IFS= read -r line; do
    # skip lines that consist of a placeholder substitution like "${VAR}" or contain only one
    case "$line" in
      *'${'*'}'*) continue ;;
    esac
    emit "$f" "mcp:secret-in-mcpjson" CRITICAL "literal token-shaped value found — replace with \${ENV_VAR} and rotate the credential"
    break
  done < <(grep -nEi '(Bearer[[:space:]]+[A-Za-z0-9._-]{16,})|(sk-[A-Za-z0-9]{16,})|(\bghp_[A-Za-z0-9]{20,})|(\bAKIA[0-9A-Z]{16}\b)|(\b(api[_-]?key|secret|token|password|access[_-]?key)[[:space:]]*[:=][[:space:]]*"[^"$]{8,}")' "$f" 2>/dev/null || true)

  # --- structural checks: no-skill-pair, over-broad-surface ---
  python3 - "$f" "$OVER_BROAD" <<'PY'
import json, os, sys, glob
path = sys.argv[1]
over = int(sys.argv[2])

def emit(sig, sev, detail):
    print(f"{path}\t{sig}\t{sev}\t{detail}")

try:
    with open(path) as fh:
        d = json.load(fh)
except Exception:
    sys.exit(0)

# Find the mcpServers block — top-level for .mcp.json, nested for ~/.claude.json
servers = None
if isinstance(d, dict):
    if "mcpServers" in d and isinstance(d["mcpServers"], dict):
        servers = d["mcpServers"]
    elif all(isinstance(v, dict) for v in d.values()) and d:
        # heuristic: looks like a bare {<name>: {...}} map
        servers = d
if not servers:
    sys.exit(0)

home = os.environ.get("HOME", "")
project_dir = os.path.dirname(os.path.dirname(os.path.abspath(path)))  # heuristic project root

for name, cfg in servers.items():
    if not isinstance(cfg, dict):
        continue

    # no-skill-pair — look in user + project skills dirs
    candidates = []
    for base in (f"{home}/.claude/skills", f"{project_dir}/skills",
                 f"{project_dir}/.claude/skills"):
        candidates += glob.glob(f"{base}/{name}*/SKILL.md")
    if not candidates:
        emit("mcp:no-skill-pair", "LOW",
             f"server {name!r} has no paired wrapper skill — scaffold one with disable-model-invocation: true")

    # over-broad-surface — only if metadata is present (heuristic)
    tools = cfg.get("tools")
    if isinstance(tools, list) and len(tools) > over:
        emit("mcp:over-broad-surface", "MEDIUM",
             f"server {name!r} exposes {len(tools)} tools (> {over}) — wrap with a disable-model-invocation skill")
PY
done
