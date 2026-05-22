#!/usr/bin/env bash
# lib-track.sh — shared helpers for the shipped, user-facing calibration iteration track.
# Sourced by snapshot.sh and compare.sh; never executed directly.
#
# This is the SHIPPED analogue of the author-only tests/eval harness: it answers
# "is calibration improving MY setup over iterations?" with the same deterministic discipline
# (a structural floor + correctly-scoped lint keyed on stable signatures) — but it grades the
# user's OWN project config, so the floor is calibration-doctor's structural check (NOT the
# plugin's gate suite) and durability is dropped (that re-introduction test only exercises the
# plugin's own write-guards, which is meaningless for a user repo).
#
# Why this and not /calibrate's built-in delta: that delta is circular (same evaluator + rubric
# the calibrator optimizes against) and non-deterministic. This track measures only signals that
# are deterministic and independent of what the calibrator changes.
#
# Portable Bash 3.2: no mapfile/readarray; printf for emission; greps that may miss get || true.

_TRACK_LIB_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# skills/ root — two levels up from skills/calibration-track/scripts/
TRACK_SKILLS_DIR="$(CDPATH='' cd -- "$_TRACK_LIB_DIR/../.." && pwd)"
TRACK_DOCTOR="$TRACK_SKILLS_DIR/calibration-doctor/scripts/doctor.sh"

# Snapshot schema version — bump on a breaking field change so compare.sh can refuse mismatches.
# shellcheck disable=SC2034
TRACK_SCHEMA_VERSION="1"

# The nine canonical features, in canonical order (mirrors the bundles + signatures catalogue).
TRACK_FEATURES="claude-md rules settings skills subagents hooks mcp plugins general"

# jq presence (TRACK_FORCE_NO_JQ=1 forces the printf fallback, for testing the degraded path).
track_have_jq() {
  [ "${TRACK_FORCE_NO_JQ:-0}" = "1" ] && return 1
  command -v jq >/dev/null 2>&1
}

# resolve_base_ref <project_dir> — print the commit of the last PR merged onto main, with
# fallbacks; empty when not a git repo / no main lineage. This is the "sync with main" anchor.
resolve_base_ref() {
  local proj="$1" ref=""
  git -C "$proj" rev-parse --git-dir >/dev/null 2>&1 || return 0
  ref="$(git -C "$proj" log --first-parent --merges -n1 --format=%H main 2>/dev/null || true)"
  [ -n "$ref" ] || ref="$(git -C "$proj" log --first-parent --merges -n1 --format=%H origin/main 2>/dev/null || true)"
  [ -n "$ref" ] || ref="$(git -C "$proj" merge-base HEAD main 2>/dev/null || true)"
  [ -n "$ref" ] || ref="$(git -C "$proj" merge-base HEAD origin/main 2>/dev/null || true)"
  printf '%s' "$ref"
}

# materialize_ref <project_dir> <ref> <dest_dir> — extract the config surfaces as of <ref> into
# <dest_dir> so the floor + lint can grade that historical tree deterministically.
materialize_ref() {
  local proj="$1" ref="$2" dest="$3" p
  local paths=()
  for p in CLAUDE.md .claude .mcp.json AGENTS.md; do
    if git -C "$proj" cat-file -e "$ref:$p" 2>/dev/null; then paths+=("$p"); fi
  done
  [ "${#paths[@]}" -gt 0 ] || return 0
  git -C "$proj" archive "$ref" -- "${paths[@]}" 2>/dev/null | tar -x -C "$dest" 2>/dev/null || true
}

# run_track_floor <tree_dir> <out_tsv> — run calibration-doctor over <tree_dir>; tally statuses.
# Sets TRACK_FLOOR_BROKEN / TRACK_FLOOR_WARN / TRACK_FLOOR_OK. A broken check is the regression veto.
run_track_floor() {
  local tree="$1" out="$2" status broken=0 warn=0 ok=0
  : > "$out"
  [ -f "$TRACK_DOCTOR" ] && { bash "$TRACK_DOCTOR" "$tree" 2>/dev/null >> "$out" || true; }
  while IFS="$(printf '\t')" read -r _ status _; do
    case "$status" in
      broken) broken=$((broken + 1)) ;;
      warn)   warn=$((warn + 1)) ;;
      ok)     ok=$((ok + 1)) ;;
    esac
  done < "$out"
  TRACK_FLOOR_BROKEN=$broken
  TRACK_FLOOR_WARN=$warn
  TRACK_FLOOR_OK=$ok
}

# run_track_lint <tree_dir> <scope> <out_tsv> — drive every bundle's lint.sh over the scoped
# instance set. scope=project keeps only the project's own .claude/** (deterministic, this-repo);
# scope=all keeps everything enumerate emits (diagnostic — sweeps user config + plugin cache).
run_track_lint() {
  local tree="$1" scope="$2" out="$3" feat lint en files
  : > "$out"
  for feat in $TRACK_FEATURES; do
    lint="$TRACK_SKILLS_DIR/calibrate-$feat/scripts/lint.sh"
    [ -f "$lint" ] || continue
    if [ "$feat" = "general" ]; then
      bash "$lint" "$tree" 2>/dev/null >> "$out" || true
      continue
    fi
    en="$TRACK_SKILLS_DIR/calibrate-$feat/scripts/enumerate.sh"
    [ -f "$en" ] || continue
    files="$(bash "$en" "$tree" 2>/dev/null \
      | awk -F"$(printf '\t')" -v s="$scope" 'NF>=2 && (s=="all" || $1=="project"){print $2}' || true)"
    [ -n "$files" ] || continue
    printf '%s\n' "$files" | tr '\n' '\0' \
      | xargs -0 bash "$lint" 2>/dev/null >> "$out" || true
  done
}

# --- snapshot emitters (read globals set by snapshot.sh; print JSON to stdout) -------------------

emit_track_snapshot_jq() {
  jq -n \
    --arg schema "$TRACK_SCHEMA_VERSION" \
    --arg ts "$GENERATED_AT" \
    --arg sha "$SHORT_SHA" \
    --arg dirty "$GIT_DIRTY" \
    --arg scope "$SCOPE" \
    --arg kind "$KIND" \
    --arg base_ref "$BASE_REF_SHA" \
    --rawfile floor_raw "$FLOOR_TSV" \
    --rawfile lint_raw "$LINT_TSV" '
    def nz: split("\n") | map(select(length > 0));
    def sevrank: {"CRITICAL":5,"HIGH":4,"MEDIUM":3,"LOW":2,"INFO":1}[.] // 0;
    (($floor_raw|nz) | map(split("\t") | {check:.[0], status:.[1], detail:.[2]}))            as $fl |
    (($lint_raw |nz) | map(split("\t") | {path:.[0], signature:.[1], severity:.[2], detail:.[3]})) as $f |
    ($fl | map(select(.status=="broken")) | length) as $broken |
    {
      schema_version: $schema,
      generated_at: $ts,
      kind: $kind,
      git: { short_sha: $sha, dirty: ($dirty == "1"),
             base_ref_sha: (if $base_ref == "" then null else $base_ref end) },
      scope: $scope,
      degraded: false,
      floor: {
        broken: $broken,
        warn:  ($fl | map(select(.status=="warn")) | length),
        ok:    ($fl | map(select(.status=="ok"))   | length),
        green: ($broken == 0),
        checks: $fl
      },
      lint: {
        total_findings: ($f | length),
        by_severity:  ($f | group_by(.severity)  | map({key:.[0].severity, value:length}) | from_entries),
        by_signature: ($f | group_by(.signature) | map({signature:.[0].signature, severity:(max_by(.severity|sevrank).severity), count:length}) | sort_by(.signature)),
        findings:     ($f | sort_by(.signature, .path))
      }
    }'
}

# Degraded fallback (jq absent): same shape minus the findings array; severities are a fixed enum
# and signatures match [a-z0-9:-]+, so plain awk emission is safe.
_track_by_severity_pairs() {
  awk -F"$(printf '\t')" 'NF>=3{c[$3]++}
    END{ first=1; for(s in c){ if(!first) printf ","; printf "\"%s\":%d", s, c[s]; first=0 } }' "$LINT_TSV"
}
_track_by_signature_objs() {
  awk -F"$(printf '\t')" 'NF>=3{cnt[$2]++; sev[$2]=$3}
    END{ first=1; for(g in cnt){ if(!first) printf ","; printf "{\"signature\":\"%s\",\"severity\":\"%s\",\"count\":%d}", g, sev[g], cnt[g]; first=0 } }' "$LINT_TSV"
}
_track_floor_check_objs() {
  awk -F"$(printf '\t')" 'BEGIN{first=1} NF>=3{ d=$3; gsub(/\\/,"\\\\",d); gsub(/"/,"\\\"",d);
    if(!first) printf ","; printf "{\"check\":\"%s\",\"status\":\"%s\",\"detail\":\"%s\"}", $1, $2, d; first=0 }' "$FLOOR_TSV"
}

emit_track_snapshot_printf() {
  local dirty_b green_b total base_json
  if [ "$GIT_DIRTY" = "1" ]; then dirty_b="true"; else dirty_b="false"; fi
  if [ "${TRACK_FLOOR_BROKEN:-0}" -eq 0 ]; then green_b="true"; else green_b="false"; fi
  if [ -z "$BASE_REF_SHA" ]; then base_json="null"; else base_json="\"$BASE_REF_SHA\""; fi
  total="$(awk 'END{print NR+0}' "$LINT_TSV")"
  printf '{\n'
  printf '  "schema_version": "%s",\n' "$TRACK_SCHEMA_VERSION"
  printf '  "generated_at": "%s",\n' "$GENERATED_AT"
  printf '  "kind": "%s",\n' "$KIND"
  printf '  "git": { "short_sha": "%s", "dirty": %s, "base_ref_sha": %s },\n' "$SHORT_SHA" "$dirty_b" "$base_json"
  printf '  "scope": "%s",\n' "$SCOPE"
  printf '  "degraded": true,\n'
  printf '  "floor": { "broken": %d, "warn": %d, "ok": %d, "green": %s, "checks": [%s] },\n' \
    "${TRACK_FLOOR_BROKEN:-0}" "${TRACK_FLOOR_WARN:-0}" "${TRACK_FLOOR_OK:-0}" "$green_b" "$(_track_floor_check_objs)"
  printf '  "lint": { "findings_omitted": true, "total_findings": %d, "by_severity": {%s}, "by_signature": [%s] }\n' \
    "$total" "$(_track_by_severity_pairs)" "$(_track_by_signature_objs)"
  printf '}\n'
}

emit_track_snapshot() { if track_have_jq; then emit_track_snapshot_jq; else emit_track_snapshot_printf; fi; }

# One compact line for the history.jsonl time series (jq-independent; computed from globals).
emit_track_ledger_line() {
  local snap_rel="$1" total green_b degraded_b
  total="$(awk 'END{print NR+0}' "$LINT_TSV")"
  if [ "${TRACK_FLOOR_BROKEN:-0}" -eq 0 ]; then green_b="true"; else green_b="false"; fi
  if track_have_jq; then degraded_b="false"; else degraded_b="true"; fi
  printf '{"schema_version":"%s","generated_at":"%s","short_sha":"%s","scope":"%s","kind":"iteration","floor_green":%s,"floor_broken":%d,"findings_total":%d,"by_severity":{%s},"snapshot":"%s","degraded":%s}\n' \
    "$TRACK_SCHEMA_VERSION" "$GENERATED_AT" "$SHORT_SHA" "$SCOPE" "$green_b" "${TRACK_FLOOR_BROKEN:-0}" \
    "$total" "$(_track_by_severity_pairs)" "$snap_rel" "$degraded_b"
}
