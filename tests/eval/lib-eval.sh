#!/usr/bin/env bash
# lib-eval.sh — shared helpers for the deterministic calibration eval harness.
# Sourced by run-eval.sh and compare-eval.sh; never executed directly.
#
# The harness implements the canonical "did calibration improve results?" measure:
#   floor (gate suite) + correctly-scoped lint + (optional) durability re-introduction.
# It is author-only (lives under tests/, not a shipped plugin component) and deterministic.

# Resolve this file's dir, then source the gate suite's lib for gates_repo_root / gates_frontmatter.
_EVAL_LIB_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../gates/lib.sh
. "$_EVAL_LIB_DIR/../gates/lib.sh"

# Snapshot schema version — bump on a breaking field change.
# shellcheck disable=SC2034
EVAL_SCHEMA_VERSION="1"

# The nine canonical features, in canonical order (mirrors GATES_FEATURES from gates/lib.sh).
# shellcheck disable=SC2034
EVAL_FEATURES="claude-md rules settings skills subagents hooks mcp plugins general"

# jq presence (cached env override EVAL_FORCE_NO_JQ=1 forces the printf fallback, for testing).
eval_have_jq() {
  [ "${EVAL_FORCE_NO_JQ:-0}" = "1" ] && return 1
  command -v jq >/dev/null 2>&1
}

# scope_files <bundle> <scope> — print newline-separated instance paths for a file-list bundle.
# scope=shipped → direct repo-root globs mirroring the gates' definition of "what ships"
#                 (NOT enumerate.sh, which sweeps ~/.claude/plugins/cache and mislabels it plugin-self).
# scope=all     → the bundle's enumerate.sh verbatim (user + project + plugin-self + cache).
# `general` is special (project-dir synthesizer) and is handled by the caller, not here.
# Always exits 0, even when it emits nothing (a bundle with zero shipped instances).
scope_files() {
  local bundle="$1" scope="$2"
  if [ "$scope" = "all" ]; then
    local en="skills/calibrate-${bundle}/scripts/enumerate.sh"
    if [ -f "$en" ]; then
      bash "$en" "$EVAL_REPO_ROOT" 2>/dev/null | awk -F'\t' 'NF>=2{print $2}' || true
    fi
    return 0
  fi
  # shipped scope: deterministic globs over the repo payload only.
  case "$bundle" in
    claude-md)
      if [ -f CLAUDE.md ]; then printf '%s\n' "CLAUDE.md"; fi ;;
    rules)
      find rules -maxdepth 1 -name '*.md' ! -name 'CLAUDE.md' 2>/dev/null | sort ;;
    skills)
      find skills -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null | sort ;;
    subagents)
      find agents -maxdepth 1 -name 'calibration-*.md' 2>/dev/null | sort ;;
    hooks)
      find hooks -maxdepth 1 \( -name '*.sh' -o -name 'hooks.json' \) 2>/dev/null | sort ;;
    plugins)
      if [ -f .claude-plugin/plugin.json ]; then printf '%s\n' ".claude-plugin/plugin.json"; fi ;;
    settings|mcp)
      : ;;  # this repo ships none; recorded as instances:0 by the caller
    *)
      : ;;
  esac
  return 0
}

# bundle_lint_invoke <bundle> [files...] — run a bundle's lint.sh and print its TSV.
# general takes the project dir; the other eight take a file-path list. lint.sh always exits 0.
bundle_lint_invoke() {
  local bundle="$1"; shift
  local lint="skills/calibrate-${bundle}/scripts/lint.sh"
  [ -f "$lint" ] || return 0
  if [ "$bundle" = "general" ]; then
    bash "$lint" "$EVAL_REPO_ROOT" 2>/dev/null || true
  else
    [ "$#" -gt 0 ] || return 0
    bash "$lint" "$@" 2>/dev/null || true
  fi
  return 0
}

# --- result helpers (jq-independent; safe to embed because severities are a fixed enum, ----------
# --- signatures are [a-z0-9:-]+, gate names are filenames, statuses are ok|FAIL|SKIP) -------------

# {"INFO":3,"MEDIUM":2}  (inner pairs only — caller wraps in braces)
_by_severity_pairs() {
  awk -F'\t' 'NF>=3{c[$3]++}
    END{ first=1; for(s in c){ if(!first) printf ","; printf "\"%s\":%d", s, c[s]; first=0 } }' "$LINT_TSV"
}

# {"signature":..,"severity":..,"count":N},...  (array elements — caller wraps in brackets)
_by_signature_objs() {
  awk -F'\t' 'NF>=3{cnt[$2]++; sev[$2]=$3}
    END{ first=1; for(g in cnt){ if(!first) printf ","; printf "{\"signature\":\"%s\",\"severity\":\"%s\",\"count\":%d}", g, sev[g], cnt[g]; first=0 } }' "$LINT_TSV"
}

_floor_gate_objs() {
  awk -F'\t' 'BEGIN{first=1} NF>=3{ if(!first) printf ","; printf "{\"gate\":\"%s\",\"exit\":%d,\"status\":\"%s\"}", $1, $2, $3; first=0 }' "$FLOOR_TSV"
}

_durab_objs() {
  awk -F'\t' 'BEGIN{first=1} NF>=4{ if(!first) printf ","; printf "{\"check\":\"%s\",\"expected\":\"%s\",\"got\":\"%s\",\"pass\":%s}", $1, $2, $3, ($4=="pass"?"true":"false"); first=0 }' "$DURAB_TSV"
}

# durab_emit <check> <expected> <got> <pass|fail|skip>
durab_emit() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$DURAB_TSV"; }

# --- snapshot emitters (read globals set by run-eval; print JSON to stdout) -----------------------

emit_snapshot_jq() {
  local durability_ran_json="false"
  [ "${DURABILITY_RAN:-0}" = "1" ] && durability_ran_json="true"
  jq -n \
    --arg schema "$EVAL_SCHEMA_VERSION" \
    --arg ts "$GENERATED_AT" \
    --arg sha "$SHORT_SHA" \
    --arg dirty "$GIT_DIRTY" \
    --arg scope "$SCOPE" \
    --argjson floor_pass "$FLOOR_PASS" \
    --argjson floor_fail "$FLOOR_FAIL" \
    --argjson durability_ran "$durability_ran_json" \
    --rawfile floor_raw "$FLOOR_TSV" \
    --rawfile lint_raw "$LINT_TSV" \
    --rawfile durab_raw "$DURAB_TSV" '
    def nz: split("\n") | map(select(length > 0));
    def sevrank: {"CRITICAL":5,"HIGH":4,"MEDIUM":3,"LOW":2,"INFO":1}[.] // 0;
    (($floor_raw|nz) | map(split("\t") | {gate:.[0], exit:(.[1]|tonumber), status:.[2]}))            as $gates |
    (($lint_raw |nz) | map(split("\t") | {path:.[0], signature:.[1], severity:.[2], detail:.[3]}))   as $f |
    (($durab_raw|nz) | map(split("\t") | {check:.[0], expected:.[1], got:.[2], pass:(.[3]=="pass")})) as $d |
    {
      schema_version: $schema,
      generated_at: $ts,
      git: { short_sha: $sha, dirty: ($dirty == "1") },
      scope: $scope,
      degraded: false,
      floor: { passed: $floor_pass, failed: $floor_fail, green: ($floor_fail == 0), gates: $gates },
      lint: {
        total_findings: ($f | length),
        by_severity:  ($f | group_by(.severity)  | map({key:.[0].severity, value:length}) | from_entries),
        by_signature: ($f | group_by(.signature) | map({signature:.[0].signature, severity:(max_by(.severity|sevrank).severity), count:length}) | sort_by(.signature)),
        findings:     ($f | sort_by(.signature, .path))
      },
      durability: (if $durability_ran then {ran:true, all_pass:(($d|length) > 0 and all($d[]; .pass)), checks:$d} else {ran:false} end)
    }'
}

emit_snapshot_printf() {
  local dirty_b green_b total
  if [ "$GIT_DIRTY" = "1" ]; then dirty_b="true"; else dirty_b="false"; fi
  if [ "$FLOOR_FAIL" -eq 0 ]; then green_b="true"; else green_b="false"; fi
  total="$(awk 'END{print NR+0}' "$LINT_TSV")"
  printf '{\n'
  printf '  "schema_version": "%s",\n' "$EVAL_SCHEMA_VERSION"
  printf '  "generated_at": "%s",\n' "$GENERATED_AT"
  printf '  "git": { "short_sha": "%s", "dirty": %s },\n' "$SHORT_SHA" "$dirty_b"
  printf '  "scope": "%s",\n' "$SCOPE"
  printf '  "degraded": true,\n'
  printf '  "floor": { "passed": %d, "failed": %d, "green": %s, "gates": [%s] },\n' \
    "$FLOOR_PASS" "$FLOOR_FAIL" "$green_b" "$(_floor_gate_objs)"
  printf '  "lint": { "findings_omitted": true, "total_findings": %d, "by_severity": {%s}, "by_signature": [%s] },\n' \
    "$total" "$(_by_severity_pairs)" "$(_by_signature_objs)"
  if [ "${DURABILITY_RAN:-0}" = "1" ]; then
    local allp
    allp="$(awk -F'\t' 'BEGIN{a=1} NF>=4{ if($4!="pass") a=0 } END{print (NR>0 && a)?"true":"false"}' "$DURAB_TSV")"
    printf '  "durability": { "ran": true, "all_pass": %s, "checks": [%s] }\n' "$allp" "$(_durab_objs)"
  else
    printf '  "durability": { "ran": false }\n'
  fi
  printf '}\n'
}

emit_snapshot() { if eval_have_jq; then emit_snapshot_jq; else emit_snapshot_printf; fi; }

# One compact line for the history.jsonl time series (computed from globals; jq-independent).
emit_ledger_line() {
  local snap_base="$1" total green_b degraded_b
  total="$(awk 'END{print NR+0}' "$LINT_TSV")"
  if [ "$FLOOR_FAIL" -eq 0 ]; then green_b="true"; else green_b="false"; fi
  if eval_have_jq; then degraded_b="false"; else degraded_b="true"; fi
  printf '{"schema_version":"%s","generated_at":"%s","short_sha":"%s","scope":"%s","floor_green":%s,"findings_total":%d,"by_severity":{%s},"snapshot":"%s","degraded":%s}\n' \
    "$EVAL_SCHEMA_VERSION" "$GENERATED_AT" "$SHORT_SHA" "$SCOPE" "$green_b" "$total" "$(_by_severity_pairs)" "$snap_base" "$degraded_b"
}
