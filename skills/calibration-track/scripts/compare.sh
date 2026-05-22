#!/usr/bin/env bash
# compare.sh — diff two iteration-track snapshots and report improvement / regression.
#
# Modes (resolved against <project>/.claude/calibration/track):
#   compare.sh <project-dir>                 the last two iteration snapshots (this vs previous)
#   compare.sh <project-dir> --vs-baseline   baseline.json (last main merge) vs newest iteration
#
# Prints a before->after severity table + floor movement + per-signature classification
# (new | resolved | improved | regressed | unchanged), an improvement note, and a verdict.
# Requires jq. Exit: 1 if a REGRESSION is detected — floor went green->red, a new CRITICAL/HIGH
# finding, or the CRITICAL/HIGH count rose. --strict also fails on a new/regressed MEDIUM.
set -Eeuo pipefail

_CMP_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=lib-track.sh
. "$_CMP_DIR/lib-track.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf 'compare: jq is required (analysis tool — no degraded mode).\n' >&2
  exit 1
fi

PROJECT=""
MODE="vs-previous"
STRICT=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --vs-baseline) MODE="vs-baseline" ;;
    --strict)      STRICT=1 ;;
    -h|--help)     sed -n '2,15p' "$0"; exit 0 ;;
    --*)           printf 'compare: unknown option: %s\n' "$1" >&2; exit 1 ;;
    *)             [ -z "$PROJECT" ] && PROJECT="$1" || { printf 'compare: too many args\n' >&2; exit 1; } ;;
  esac
  shift
done
PROJECT="${PROJECT:-$(pwd)}"
PROJECT="$(CDPATH='' cd -- "$PROJECT" 2>/dev/null && pwd || printf '%s' "$PROJECT")"
TRACK_DIR="$PROJECT/.claude/calibration/track"
LEDGER="$TRACK_DIR/history.jsonl"

# Resolve the Nth-from-end ledger snapshot (.snapshot is relative to TRACK_DIR).
_ledger_nth_from_end() {
  [ -f "$LEDGER" ] || return 1
  tail -n "$1" "$LEDGER" 2>/dev/null | head -n 1 | jq -r '.snapshot // empty' 2>/dev/null
}
_resolve() { case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$TRACK_DIR/$1" ;; esac; }

BASELINE=""
CURRENT=""
case "$MODE" in
  vs-baseline)
    BASELINE="$TRACK_DIR/baseline.json"
    rel="$(_ledger_nth_from_end 1)"; [ -n "$rel" ] && CURRENT="$(_resolve "$rel")"
    ;;
  vs-previous)
    # Need at least two distinct iterations; one line means this is the first tracked iteration.
    nlines="$( [ -f "$LEDGER" ] && grep -c . "$LEDGER" 2>/dev/null || echo 0 )"
    if [ "${nlines:-0}" -lt 2 ]; then
      printf 'need-two-iterations\n'
      printf 'compare: only one iteration recorded — run /calibration-track again after a change.\n' >&2
      exit 0
    fi
    brel="$(_ledger_nth_from_end 2)"; crel="$(_ledger_nth_from_end 1)"
    [ -n "$brel" ] && BASELINE="$(_resolve "$brel")"
    [ -n "$crel" ] && CURRENT="$(_resolve "$crel")"
    ;;
esac

if [ -z "$BASELINE" ] || [ ! -f "$BASELINE" ]; then
  if [ "$MODE" = "vs-baseline" ]; then
    printf 'no-baseline\n'
    printf 'compare: no baseline.json yet — run snapshot.sh --baseline first.\n' >&2
  else
    printf 'need-two-iterations\n'
    printf 'compare: only one iteration recorded — run /calibration-track again after a change.\n' >&2
  fi
  exit 0
fi
if [ -z "$CURRENT" ] || [ ! -f "$CURRENT" ]; then
  printf 'no-current\n'
  printf 'compare: no current iteration snapshot found — run /calibration-track first.\n' >&2
  exit 0
fi
for f in "$BASELINE" "$CURRENT"; do
  jq empty "$f" 2>/dev/null || { printf 'compare: not valid JSON: %s\n' "$f" >&2; exit 1; }
done

# Single jq pass: build rendered lines + regression / improvement booleans.
OUT="$(jq -s '
  def num($o; $k): ($o.lint.by_severity[$k] // 0);
  def rpad($n): . + (" " * (if ($n - length) > 0 then $n - length else 0 end));
  def signed: if . > 0 then "+\(.)" else "\(.)" end;
  .[0] as $b | .[1] as $c
  | ["CRITICAL","HIGH","MEDIUM","LOW","INFO"] as $sevs
  | ($b.lint.by_signature // []) as $bs
  | ($c.lint.by_signature // []) as $cs
  | ($bs | map({key:.signature, value:.}) | from_entries) as $bm
  | ($cs | map({key:.signature, value:.}) | from_entries) as $cm
  | (($bs | map(.signature)) + ($cs | map(.signature)) | unique) as $sigs
  | [ $sigs[] | . as $s
      | ($bm[$s].count // 0) as $bn | ($cm[$s].count // 0) as $cn
      | { signature:$s, severity:($cm[$s].severity // $bm[$s].severity), before:$bn, after:$cn,
          class:(if $bn==0 and $cn>0 then "new"
                 elif $bn>0 and $cn==0 then "resolved"
                 elif $cn>$bn then "regressed"
                 elif $cn<$bn then "improved" else "unchanged" end) } ] as $rows
  | ($b.floor.green and ($c.floor.green | not)) as $floor_broke
  | (any($rows[]; .class=="new" and (.severity=="CRITICAL" or .severity=="HIGH"))) as $new_hi
  | ((num($c;"CRITICAL") > num($b;"CRITICAL")) or (num($c;"HIGH") > num($b;"HIGH"))) as $sev_up
  | ($floor_broke or $new_hi or $sev_up) as $regressed
  | (any($rows[]; (.class=="new" or .class=="regressed") and .severity=="MEDIUM")) as $med_reg
  | ([ $sevs[] | (num($b;.)) - (num($c;.)) ] | add) as $net_resolved
  | ((($c.floor.broken // 0) < ($b.floor.broken // 0)) or ($net_resolved > 0)) as $any_progress
  | ($any_progress and ($regressed | not)) as $improved
  | { regressed: $regressed, strict_regressed: ($regressed or $med_reg), improved: $improved,
      lines: (
        [ "Comparing snapshots:",
          "  base:    \($b.kind) @ \($b.git.short_sha)  \($b.generated_at)",
          "  current: \($c.kind) @ \($c.git.short_sha)  \($c.generated_at)",
          "",
          "  \("severity"|rpad(10)) \("before"|rpad(7)) \("after"|rpad(7)) delta" ]
        + [ $sevs[] | . as $s | (num($b;$s)) as $bn | (num($c;$s)) as $cn
            | "  \($s|rpad(10)) \(($bn|tostring)|rpad(7)) \(($cn|tostring)|rpad(7)) \(($cn-$bn)|signed)" ]
        + [ "  floor green: \(if $b.floor.green then "yes" else "no" end) -> \(if $c.floor.green then "yes" else "no" end)  (broken \($b.floor.broken // 0) -> \($c.floor.broken // 0))",
            "",
            "signature changes:" ]
        + ( [ $rows[] | select(.class != "unchanged") ]
            | if length == 0 then [ "  (none — every signature unchanged)" ]
              else sort_by(.signature) | map("  [\(.class|rpad(9))] \(.severity|rpad(8)) \(.signature|rpad(36)) \(.before) -> \(.after)") end )
        + [ "",
            ("verdict: " + (if $regressed then "REGRESSION" elif $improved then "IMPROVED" else "no change of note" end)) ]
      ) }
' "$BASELINE" "$CURRENT")"

printf '%s\n' "$OUT" | jq -r '.lines[]'

REG="$(printf '%s' "$OUT" | jq -r '.regressed')"
SREG="$(printf '%s' "$OUT" | jq -r '.strict_regressed')"
if [ "$STRICT" -eq 1 ]; then DECISION="$SREG"; else DECISION="$REG"; fi
[ "$DECISION" = "true" ] && exit 1
exit 0
