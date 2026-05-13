#!/usr/bin/env bash
# lint.sh — check installed_plugins.json and (if applicable) a plugin's own manifest.
# Usage: lint.sh <installed_plugins.json | manifest.json | <a path emitted as self-misplaced>>
set -euo pipefail
emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

for f in "$@"; do
  case "$f" in *.tmpl) continue ;; esac
  [ -e "$f" ] || { emit "$f" "plugin:not-found" HIGH "path does not exist"; continue; }

  base=$(basename "$f")
  case "$base" in
    plugin.json)
      if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
        emit "$f" "plugin:invalid-manifest-json" HIGH "manifest is not valid JSON"
        continue
      fi
      python3 - "$f" <<'PY' || true
import json, sys
f = sys.argv[1]
d = json.load(open(f))
if not d.get("name"):
    print(f"{f}\tplugin:missing-name\tHIGH\tmanifest lacks 'name'")
if not d.get("version"):
    print(f"{f}\tplugin:missing-version\tLOW\tno 'version' — every commit counts as a new version on git distribution")
PY
      # check sibling component placement
      proot=$(dirname "$(dirname "$f")")
      for sub in skills agents hooks .mcp.json .lsp.json monitors bin commands; do
        if [ -e "$proot/.claude-plugin/$sub" ]; then
          emit "$f" "plugin:misplaced-components" HIGH ".claude-plugin/$sub exists — components belong at the plugin ROOT, not inside .claude-plugin/"
        fi
      done
      if [ -d "$proot/commands" ] && [ ! -d "$proot/skills" ]; then
        emit "$f" "plugin:legacy-commands-only" LOW "plugin uses commands/ but not skills/ — prefer skills for new plugins"
      fi
      ;;
    installed_plugins.json)
      if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
        emit "$f" "plugin:invalid-manifest-json" HIGH "installed_plugins.json is not valid JSON"
      fi
      ;;
    known_marketplaces.json)
      python3 - "$f" <<'PY' || true
import json, sys
f = sys.argv[1]
try:
    d = json.load(open(f))
    seen = {}
    items = d.values() if isinstance(d, dict) else (d if isinstance(d, list) else [])
    for m in items:
        url = (m or {}).get("url") if isinstance(m, dict) else None
        if url:
            seen[url] = seen.get(url, 0) + 1
    for url, n in seen.items():
        if n > 1:
            print(f"{f}\tplugin:duplicate-marketplaces\tLOW\tmarketplace registered {n}× ({url}) — deduplicate via /plugin")
except Exception:
    pass
PY
      ;;
  esac
done
