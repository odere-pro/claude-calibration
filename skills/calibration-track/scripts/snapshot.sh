#!/usr/bin/env bash
# snapshot.sh — produce one deterministic snapshot of a Claude Code setup for the iteration track.
#
# Two modes:
#   (default, iteration) snapshot the working tree → .claude/calibration/track/snapshots/<ts>.json
#                        and append a line to .claude/calibration/track/history.jsonl
#   --baseline           snapshot the config AS OF the last PR merged onto main (the "base") →
#                        .claude/calibration/track/baseline.json, keyed by the merge ref SHA.
#                        Re-syncs automatically when main advances; --reset-baseline forces it.
#
# Each snapshot = a structural floor (calibration-doctor) + correctly-scoped lint over the nine
# features. Deterministic, and independent of /calibrate's circular built-in delta.
#
# Usage: snapshot.sh <project-dir> [--baseline] [--ref <git-ref>] [--scope project|all]
#                    [--reset-baseline] [--no-write]
set -Eeuo pipefail

_SNAP_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=lib-track.sh
. "$_SNAP_DIR/lib-track.sh"

usage() { sed -n '2,17p' "$0"; }

PROJECT=""
MODE="iteration"
SCOPE="project"
REF=""
RESET=0
NO_WRITE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --baseline)        MODE="baseline" ;;
    --ref)             shift; REF="${1:-}" ;;
    --ref=*)           REF="${1#--ref=}" ;;
    --scope)           shift; SCOPE="${1:-}" ;;
    --scope=*)         SCOPE="${1#--scope=}" ;;
    --reset-baseline)  RESET=1 ;;
    --no-write)        NO_WRITE=1 ;;
    -h|--help)         usage; exit 0 ;;
    --*)               printf 'snapshot: unknown option: %s\n' "$1" >&2; usage >&2; exit 1 ;;
    *)                 [ -z "$PROJECT" ] && PROJECT="$1" || { printf 'snapshot: too many args\n' >&2; exit 1; } ;;
  esac
  shift
done

PROJECT="${PROJECT:-$(pwd)}"
PROJECT="$(CDPATH='' cd -- "$PROJECT" 2>/dev/null && pwd || printf '%s' "$PROJECT")"
case "$SCOPE" in
  project|all) ;;
  *) printf 'snapshot: --scope must be project|all (got: %s)\n' "$SCOPE" >&2; exit 1 ;;
esac

TRACK_DIR="$PROJECT/.claude/calibration/track"

WORKDIR="$(mktemp -d 2>/dev/null || mktemp -d -t caltrack)"
trap 'rm -rf "$WORKDIR"' EXIT INT TERM
FLOOR_TSV="$WORKDIR/floor.tsv"; : > "$FLOOR_TSV"
LINT_TSV="$WORKDIR/lint.tsv";   : > "$LINT_TSV"

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FNAME_TS="$(date -u +%Y%m%dT%H%M%SZ)"
SHORT_SHA="$(git -C "$PROJECT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ -n "$(git -C "$PROJECT" status --porcelain 2>/dev/null || true)" ]; then GIT_DIRTY=1; else GIT_DIRTY=0; fi

# Globals consumed by the lib emitters.
BASE_REF_SHA=""
KIND="iteration"

if [ "$MODE" = "baseline" ]; then
  KIND="baseline-ref"
  [ -n "$REF" ] || REF="$(resolve_base_ref "$PROJECT")"
  if [ -z "$REF" ]; then
    printf 'no-base-ref\n'
    printf 'snapshot: no main lineage found (not a git repo, or no main branch) — skipping baseline.\n' >&2
    exit 0
  fi
  BASE_REF_SHA="$(git -C "$PROJECT" rev-parse "$REF" 2>/dev/null || printf '%s' "$REF")"

  # Already synced to this exact ref? Skip unless --reset-baseline.
  if [ "$RESET" -eq 0 ] && [ -f "$TRACK_DIR/baseline.json" ] && track_have_jq; then
    have="$(jq -r '.git.base_ref_sha // empty' "$TRACK_DIR/baseline.json" 2>/dev/null || true)"
    if [ -n "$have" ] && [ "$have" = "$BASE_REF_SHA" ]; then
      printf 'baseline-current %s\n' "$(printf '%s' "$BASE_REF_SHA" | cut -c1-12)"
      printf 'snapshot: baseline already synced to last main merge (%s).\n' \
        "$(printf '%s' "$BASE_REF_SHA" | cut -c1-12)" >&2
      exit 0
    fi
  fi

  TREE="$WORKDIR/base"
  mkdir -p "$TREE"
  materialize_ref "$PROJECT" "$REF" "$TREE"
else
  TREE="$PROJECT"
fi

run_track_floor "$TREE" "$FLOOR_TSV"
run_track_lint "$TREE" "$SCOPE" "$LINT_TSV"

if [ "$NO_WRITE" -eq 1 ]; then
  emit_track_snapshot
  exit 0
fi

mkdir -p "$TRACK_DIR/snapshots"

if [ "$MODE" = "baseline" ]; then
  emit_track_snapshot > "$TRACK_DIR/baseline.json"
  printf 'baseline-synced %s\n' "$(printf '%s' "$BASE_REF_SHA" | cut -c1-12)"
  printf 'snapshot: baseline synced to last main merge (%s).\n' \
    "$(printf '%s' "$BASE_REF_SHA" | cut -c1-12)" >&2
else
  SNAP_BASE="${FNAME_TS}-${SHORT_SHA}-${RANDOM}.json"
  emit_track_snapshot > "$TRACK_DIR/snapshots/$SNAP_BASE"
  emit_track_ledger_line "snapshots/$SNAP_BASE" >> "$TRACK_DIR/history.jsonl"
  printf 'snapshots/%s\n' "$SNAP_BASE"
  printf 'snapshot: iteration recorded (floor %s broken · %s findings).\n' \
    "${TRACK_FLOOR_BROKEN:-0}" "$(awk 'END{print NR+0}' "$LINT_TSV")" >&2
fi
