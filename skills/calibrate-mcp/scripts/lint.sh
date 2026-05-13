#!/usr/bin/env bash
# lint.sh — check MCP-bearing files against the calibrate-mcp rubric.
# Usage: lint.sh <.mcp.json | ~/.claude.json | agent.md> [...]
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -f "$f" ] || { emit "$f" "mcp:not-found" HIGH "file does not exist"; continue; }

  # Determine file type
  case "$f" in
    *.json|*.local.json)
      if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
        emit "$f" "mcp:invalid-json" HIGH "file is not valid JSON"
        continue
      fi
      # Only treat this as an MCP config if it has an mcpServers key (or the file is named .mcp.json
      # and is itself the server map). Otherwise skip — plugin.json etc. are not MCP files.
      is_mcp=$(python3 -c '
import json, sys, os
d = json.load(open(sys.argv[1]))
name = os.path.basename(sys.argv[1])
print("yes" if (isinstance(d, dict) and ("mcpServers" in d or name == ".mcp.json")) else "no")
      ' "$f" 2>/dev/null || echo no)
      [ "$is_mcp" = "yes" ] || continue

      # extract mcpServers section, check for hardcoded tokens
      python3 - "$f" <<'PY' || true
import json, re, sys, os
f = sys.argv[1]
d = json.load(open(f))
name = os.path.basename(f)
servers = d.get("mcpServers", d if name == ".mcp.json" else {})
def walk_strs(o):
    if isinstance(o, dict):
        for v in o.values(): yield from walk_strs(v)
    elif isinstance(o, list):
        for v in o: yield from walk_strs(v)
    elif isinstance(o, str): yield o
pats = [
  r"sk-[A-Za-z0-9]{16,}", r"\bAKIA[0-9A-Z]{16}\b", r"\bghp_[A-Za-z0-9]{20,}",
  r"\bxox[bp]-[A-Za-z0-9-]{20,}", r"^Bearer\s+[A-Za-z0-9._-]{20,}$"
]
hits = set()
for s in walk_strs(servers):
    if "${" in s: continue   # env-var reference is fine
    for p in pats:
        if re.search(p, s):
            hits.add(p[:20]); break
if hits:
    print(f"{f}\tmcp:secret-in-mcpjson\tCRITICAL\thardcoded token shape(s) detected ({', '.join(sorted(hits))}) — use ${{ENV_VAR}} or OAuth")
PY
      # collect server names → no-skill-pair check (best-effort)
      names=$(python3 -c '
import json, sys, os
d = json.load(open(sys.argv[1]))
name = os.path.basename(sys.argv[1])
servers = d.get("mcpServers", d if name == ".mcp.json" else {})
print(" ".join(servers.keys()) if isinstance(servers, dict) else "")
      ' "$f" 2>/dev/null)
      for n in $names; do
        # search for a paired skill (any SKILL.md mentioning this server)
        paired="no"
        for d in "$HOME/.claude/skills" "$(dirname "$f")/.claude/skills"; do
          [ -d "$d" ] || continue
          if grep -qrE "(mcp__${n}__|name:[[:space:]]*${n}\b|<server-name>[[:space:]]*${n})" "$d" 2>/dev/null; then
            paired="yes"; break
          fi
        done
        if [ "$paired" = "no" ]; then
          emit "$f" "mcp:no-skill-pair" LOW "server '$n' has no paired skill — consider scaffolding one (calibrate-skills/templates/mcp-wrapper.tmpl)"
        fi
      done
      ;;
    *.md)
      # subagent file with mcpServers frontmatter — flag bare tokens in the frontmatter
      fm=$(awk 'BEGIN{state=0} /^---$/{state++; next} state==1' "$f")
      if printf '%s' "$fm" | grep -qE '\b(sk-[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,})\b'; then
        emit "$f" "mcp:secret-in-mcpjson" CRITICAL "hardcoded token in agent's mcpServers frontmatter"
      fi
      ;;
  esac
done
