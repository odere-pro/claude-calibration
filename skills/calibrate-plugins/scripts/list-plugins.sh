#!/usr/bin/env bash
# list-plugins.sh — emit a TSV of installed plugins for the /calibrate orchestrator's Pass A0
# resolver. Used by the preprocessing block of skills/calibrate/SKILL.md and by the calibrator
# when a plugin: token is in the args.
#
# Usage: list-plugins.sh [project-dir]
# Output (one row per plugin, no header):
#   name<TAB>marketplace<TAB>version<TAB>install_path<TAB>description
#
# `marketplace` is "(local)" for an in-tree plugin (PROJECT_DIR/.claude-plugin/plugin.json).
# `description` is truncated to 200 chars to keep the inlined TSV bounded.
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

# Read description from a plugin.json (best-effort; returns empty string on miss).
read_description() {
  local manifest="$1"
  [ -f "$manifest" ] || { echo ""; return; }
  python3 -c "
import json, sys
try:
    m = json.load(open(sys.argv[1]))
    d = m.get('description', '') or ''
    print(d[:200].replace('\t', ' ').replace('\n', ' '))
except Exception:
    print('')
" "$manifest" 2>/dev/null || echo ""
}

REGISTRY="$HOME/.claude/plugins/installed_plugins.json"

if [ -f "$REGISTRY" ]; then
  # Parse the registry: keys are <name>@<marketplace>, values are arrays of install records.
  # Emit one row per record (a plugin can have user + project scope entries — we emit both).
  python3 - "$REGISTRY" <<'PY' 2>/dev/null | while IFS=$'\t' read -r name marketplace version install_path; do
import json, sys
try:
    reg = json.load(open(sys.argv[1]))
    for key, entries in (reg.get('plugins') or {}).items():
        if '@' in key:
            name, marketplace = key.split('@', 1)
        else:
            name, marketplace = key, '(unknown)'
        for entry in entries or []:
            version = entry.get('version') or 'unknown'
            install_path = entry.get('installPath') or ''
            print(f"{name}\t{marketplace}\t{version}\t{install_path}")
except Exception:
    pass
PY
    desc=$(read_description "$install_path/.claude-plugin/plugin.json")
    emit "$name" "$marketplace" "$version" "$install_path" "$desc"
  done
else
  # Fallback: glob the cache directly. Path shape: cache/<marketplace>/<name>/<version>/.claude-plugin/plugin.json
  if [ -d "$HOME/.claude/plugins/cache" ]; then
    find "$HOME/.claude/plugins/cache" -mindepth 4 -maxdepth 4 \
      -path '*/.claude-plugin/plugin.json' -print 2>/dev/null \
      | while read -r manifest; do
          plugin_dir="$(dirname "$(dirname "$manifest")")"
          version="$(basename "$plugin_dir")"
          name="$(basename "$(dirname "$plugin_dir")")"
          marketplace="$(basename "$(dirname "$(dirname "$plugin_dir")")")"
          desc=$(read_description "$manifest")
          emit "$name" "$marketplace" "$version" "$plugin_dir" "$desc"
        done
  fi
fi

# Append the in-tree plugin row when PROJECT_DIR is itself a plugin source.
if [ -f "$PROJECT/.claude-plugin/plugin.json" ]; then
  name=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('name','') or '')" "$PROJECT/.claude-plugin/plugin.json" 2>/dev/null || echo "")
  version=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('version','') or 'unknown')" "$PROJECT/.claude-plugin/plugin.json" 2>/dev/null || echo "unknown")
  desc=$(read_description "$PROJECT/.claude-plugin/plugin.json")
  if [ -n "$name" ]; then
    emit "$name" "(local)" "$version" "$PROJECT" "$desc"
  fi
fi
