#!/usr/bin/env bash
# resolve-plugin-filter.sh — normalise a /calibrate-style argument string and/or a
# .claude/calibration/config.json into the canonical CALIBRATION_PLUGIN_FILTER spec
# (include:a,b | exclude:a,b | scope:global|local), printed to stdout. Empty => all plugins.
#
# A `--plugins <val>` flag in the arguments wins; otherwise the config file is consulted.
# Shared by the /calibrate orchestrator and the calibration-audit / calibration-diff flows so
# the parse lives in one place. Invoked as `bash resolve-plugin-filter.sh …` (real bash), but the
# extraction uses awk so it does not depend on the caller's shell word-splitting.
#
# Usage: resolve-plugin-filter.sh "<ARGUMENTS>" [project-dir]
set -euo pipefail
args="${1:-}"
project="${2:-$(pwd)}"

plugins_val="$(printf '%s\n' "$args" | awk '{for(i=1;i<=NF;i++){if($i=="--plugins"){print $(i+1);exit} if($i ~ /^--plugins=/){t=$i;sub(/^--plugins=/,"",t);print t;exit}}}')"

if [ -n "$plugins_val" ]; then
  printf '%s' "$plugins_val" | awk '{val=$0} END{
    if(val==""){print "";exit}
    mode="include"; if(substr(val,1,1)=="-"){mode="exclude";val=substr(val,2)}
    n=split(val,a,","); names=""; scope=""
    for(i=1;i<=n;i++){t=a[i]; if(t=="global"||t=="local"){scope=t} else if(t!=""){names=(names==""?t:names","t)}}
    out=""; if(names!="")out=mode":"names; if(scope!="")out=(out==""?"":out"|")"scope:"scope; print out}'
  exit 0
fi

cfg="$project/.claude/calibration/config.json"
if [ -f "$cfg" ] && command -v jq >/dev/null 2>&1; then
  mode="$(jq -r '.plugins.mode // empty' "$cfg" 2>/dev/null || true)"
  names="$(jq -r '(.plugins.names // []) | join(",")' "$cfg" 2>/dev/null || true)"
  scope="$(jq -r '.plugins.scope // empty' "$cfg" 2>/dev/null || true)"
  out=""
  [ -n "$names" ] && [ -n "$mode" ] && out="$mode:$names"
  [ -n "$scope" ] && [ "$scope" != "all" ] && out="${out:+$out|}scope:$scope"
  printf '%s' "$out"
fi
