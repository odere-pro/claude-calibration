#!/usr/bin/env bash
# G2 — marketplace.json has the required shape, its plugin entry matches plugin.json,
#      and the entry omits `version` (plugin.json is the single source of truth). (CRITICAL)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

MK=".claude-plugin/marketplace.json"
PJ=".claude-plugin/plugin.json"
fail=0

[ -f "$MK" ] || { echo "  FAIL: missing $MK"; echo "G2 marketplace-shape: FAIL"; exit 1; }
[ -f "$PJ" ] || { echo "  FAIL: missing $PJ"; echo "G2 marketplace-shape: FAIL"; exit 1; }

req() { # jq-filter human-label
  if [ "$(jq -r "$1" "$MK" 2>/dev/null)" = "EMPTY" ] || [ -z "$(jq -r "$1 // empty" "$MK" 2>/dev/null)" ]; then
    echo "  FAIL: marketplace.json missing/empty: $2"
    fail=1
  fi
}
req '.name'                    'name'
req '.owner.name'              'owner.name'
req '.plugins[0].name'         'plugins[0].name'
req '.plugins[0].source'       'plugins[0].source'
req '.plugins[0].description'  'plugins[0].description'

mk_name="$(jq -r '.plugins[0].name // empty' "$MK")"
pj_name="$(jq -r '.name // empty' "$PJ")"
if [ "$mk_name" != "$pj_name" ]; then
  echo "  FAIL: plugin entry name '$mk_name' != plugin.json name '$pj_name'"
  fail=1
fi

if [ "$(jq -r '.plugins[0] | has("version")' "$MK")" = "true" ]; then
  echo "  FAIL: plugins[0] sets 'version' — remove it; plugin.json is the source of truth"
  fail=1
fi

if [ "$fail" -ne 0 ]; then echo "G2 marketplace-shape: FAIL"; exit 1; fi
echo "G2 marketplace-shape: ok"
