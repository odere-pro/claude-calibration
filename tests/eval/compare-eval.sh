#!/usr/bin/env bash
# compare-eval.sh — diff two eval snapshots and report improvement / regression over time.
#
# Selection (first match wins):
#   compare-eval.sh <baseline.json> <current.json>   explicit pair
#   compare-eval.sh --vs-baseline [current.json]      tests/eval/baseline.json vs current
#                                                      (current defaults to the newest ledger snapshot)
#   compare-eval.sh                                    the last two snapshots in history.jsonl
#
# Prints a before->after severity table + per-signature classification
# (new | resolved | improved | regressed | unchanged). Requires jq.
#
# Exit: 1 if a REGRESSION is detected — floor went green->red, a new CRITICAL/HIGH finding, or the
# CRITICAL/HIGH count rose. --strict also fails on a new/regressed MEDIUM. Otherwise 0.
set -Eeuo pipefail

_THIS_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=lib-eval.sh
. "$_THIS_DIR/lib-eval.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf 'compare-eval: jq is required (analysis tool — no degraded mode).\n' >&2
  exit 1
fi

EVAL_REPO_ROOT="$(gates_repo_root)"
EVAL_DIR="$EVAL_REPO_ROOT/tests/eval"
LEDGER="$EVAL_DIR/history.jsonl"
STRICT=0
MODE="default"
POS1=""
POS2=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --vs-baseline) MODE="vs-baseline";;
    --strict) STRICT=1;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
    --*) printf 'compare-eval: unknown option: %s\n' "$1" >&2; exit 1;;
    *) if [ -z "$POS1" ]; then POS1="$1"; elif [ -z "$POS2" ]; then POS2="$1"; else
         printf 'compare-eval: too many arguments\n' >&2; exit 1; fi;;
  esac
  shift
done

# Resolve a ledger snapshot reference (the .snapshot field is relative to tests/eval/).
_ledger_nth_from_end() {  # $1 = 1 for last, 2 for second-to-last
  [ -f "$LEDGER" ] || return 1
  tail -n "$1" "$LEDGER" 2>/dev/null | head -n 1 | jq -r '.snapshot // empty' 2>/dev/null
}
_resolve() {  # turn a ledger-relative or given path into an absolute file path
  case "$1" in
    /*) printf '%s\n' "$1";;
    *) printf '%s\n' "$EVAL_DIR/$1";;
  esac
}

BASELINE=""
CURRENT=""
case "$MODE" in
  vs-baseline)
    BASELINE="$EVAL_DIR/baseline.json"
    if [ -n "$POS1" ]; then CURRENT="$POS1"; else
      rel="$(_ledger_nth_from_end 1)"; [ -n "$rel" ] && CURRENT="$(_resolve "$rel")"
    fi
    ;;
  default)
    if [ -n "$POS1" ] && [ -n "$POS2" ]; then
      BASELINE="$POS1"; CURRENT="$POS2"
    else
      brel="$(_ledger_nth_from_end 2)"; crel="$(_ledger_nth_from_end 1)"
      [ -n "$brel" ] && BASELINE="$(_resolve "$brel")"
      [ -n "$crel" ] && CURRENT="$(_resolve "$crel")"
    fi
    ;;
esac

if [ -z "$BASELINE" ] || [ -z "$CURRENT" ]; then
  printf 'compare-eval: could not resolve a baseline + current pair.\n' >&2
  printf '  Provide two files, use --vs-baseline, or run run-eval.sh twice to populate the ledger.\n' >&2
  exit 1
fi
for f in "$BASELINE" "$CURRENT"; do
  [ -f "$f" ] || { printf 'compare-eval: snapshot not found: %s\n' "$f" >&2; exit 1; }
  jq empty "$f" 2>/dev/null || { printf 'compare-eval: not valid JSON: %s\n' "$f" >&2; exit 1; }
done

# Single jq pass: build the rendered report lines + the regression booleans.
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
  | { regressed: $regressed, strict_regressed: ($regressed or $med_reg),
      lines: (
        [ "Comparing snapshots:",
          "  baseline: \($b.scope) @ \($b.git.short_sha)  \($b.generated_at)",
          "  current:  \($c.scope) @ \($c.git.short_sha)  \($c.generated_at)",
          "",
          "  \("severity"|rpad(10)) \("before"|rpad(7)) \("after"|rpad(7)) delta" ]
        + [ $sevs[] | . as $s | (num($b;$s)) as $bn | (num($c;$s)) as $cn
            | "  \($s|rpad(10)) \(($bn|tostring)|rpad(7)) \(($cn|tostring)|rpad(7)) \(($cn-$bn)|signed)" ]
        + [ "  floor green: \(if $b.floor.green then "yes" else "no" end) -> \(if $c.floor.green then "yes" else "no" end)",
            "",
            "signature changes:" ]
        + ( [ $rows[] | select(.class != "unchanged") ]
            | if length == 0 then [ "  (none — every signature unchanged)" ]
              else sort_by(.signature) | map("  [\(.class|rpad(9))] \(.severity|rpad(8)) \(.signature|rpad(36)) \(.before) -> \(.after)") end )
        + [ "", ("verdict: " + (if $regressed then "REGRESSION" else "no regression" end)) ]
      ) }
' "$BASELINE" "$CURRENT")"

printf '%s\n' "$OUT" | jq -r '.lines[]'

REG="$(printf '%s' "$OUT" | jq -r '.regressed')"
SREG="$(printf '%s' "$OUT" | jq -r '.strict_regressed')"
if [ "$STRICT" -eq 1 ]; then DECISION="$SREG"; else DECISION="$REG"; fi
[ "$DECISION" = "true" ] && exit 1
exit 0
