#!/usr/bin/env bash
# G20 — the plugin-filter helpers behave correctly: name extraction, allow/block list, scope
# restriction, and the CLI/config resolver normalisation. (CRITICAL)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

helper="skills/lib/plugin-filter.sh"
resolver="skills/lib/resolve-plugin-filter.sh"
fail=0
note() { echo "  FAIL: $1"; fail=1; }

[ -f "$helper" ] || { echo "  FAIL: $helper missing"; echo "G20 plugin-filter: FAIL"; exit 1; }
# shellcheck source=/dev/null
. "$helper"

# --- name extraction (cache/<marketplace>/<plugin>/<version>/...) ---
got="$(cpf_extract_plugin_name "/x/.claude/plugins/cache/mkt/my-plugin/0.1.0/skills/s/SKILL.md")"
[ "$got" = "my-plugin" ] || note "extract nested => '$got' (want my-plugin)"
got="$(cpf_extract_plugin_name "/x/.claude/plugins/cache/mkt/cool/2.0.0")"
[ "$got" = "cool" ] || note "extract version-dir => '$got' (want cool)"

# --- allow/block + scope predicate ---
chk() { # desc expect(Y/N) filter name scope
  local exp="$2" got
  CALIBRATION_PLUGIN_FILTER="$3"
  if cpf_in_scope "$4" "$5"; then got=Y; else got=N; fi
  unset CALIBRATION_PLUGIN_FILTER
  [ "$got" = "$exp" ] || note "$1 => $got (want $exp)"
}
chk "empty=all"                Y ""                foo global
chk "include hit"              Y "include:foo,bar" foo global
chk "include miss"             N "include:foo,bar" zzz global
chk "exclude hit"              N "exclude:baz"     baz global
chk "exclude miss"             Y "exclude:baz"     foo global
chk "scope:global skips local" N "scope:global"    foo local
chk "scope:local keeps local"  Y "scope:local"     foo local

# --- resolver normalisation (CLI flag + config fallback) ---
[ -f "$resolver" ] || note "$resolver missing"
if [ -f "$resolver" ]; then
  rchk() { # desc args expected
    local out
    out="$(bash "$resolver" "$2" /nonexistent-project 2>/dev/null || true)"
    [ "$out" = "$3" ] || note "$1 => '$out' (want '$3')"
  }
  rchk "allow-list" "--plugins foo,bar" "include:foo,bar"
  rchk "block-list" "--plugins -baz"    "exclude:baz"
  rchk "scope only" "--plugins global"  "scope:global"
  rchk "no flag"    "tighten standards" ""
fi

if [ "$fail" -eq 0 ]; then
  echo "G20 plugin-filter: ok"
else
  echo "G20 plugin-filter: FAIL"
  exit 1
fi
