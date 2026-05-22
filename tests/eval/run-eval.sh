#!/usr/bin/env bash
# run-eval.sh — produce one deterministic calibration eval snapshot.
#
# Implements the canonical "did calibration improve results?" measure (author-only, deterministic):
#   1. floor       — run the gate suite; record per-gate exit + pass/fail tally (the regression veto)
#   2. scoped lint — per-bundle lint.sh over the TRUE shipped payload (--scope shipped, default)
#                    or the full enumerate sweep incl. user + cache (--scope all, diagnostic only)
#   3. durability  — (optional --durability) re-introduce a fixed anti-pattern on a copy and confirm
#                    a shipped guard/gate still BLOCKS it
#
# Writes a JSON snapshot under tests/eval/snapshots/ and appends a line to tests/eval/history.jsonl,
# unless --no-write (then it prints the snapshot to stdout and persists nothing).
#
# Usage: run-eval.sh [--scope shipped|all] [--durability] [--no-write] [-h|--help]
set -Eeuo pipefail

_THIS_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=lib-eval.sh
. "$_THIS_DIR/lib-eval.sh"

usage() { sed -n '2,17p' "$0"; }

SCOPE="shipped"
DURABILITY_RAN=0
WANT_DURABILITY=0
NO_WRITE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --scope) shift; SCOPE="${1:-}";;
    --scope=*) SCOPE="${1#--scope=}";;
    --durability) WANT_DURABILITY=1;;
    --no-write|--stdout) NO_WRITE=1;;
    -h|--help) usage; exit 0;;
    *) printf 'run-eval: unknown option: %s\n' "$1" >&2; usage >&2; exit 1;;
  esac
  shift
done
case "$SCOPE" in
  shipped|all) ;;
  *) printf 'run-eval: --scope must be shipped|all (got: %s)\n' "$SCOPE" >&2; exit 1;;
esac

EVAL_REPO_ROOT="$(gates_repo_root)"
cd "$EVAL_REPO_ROOT"

WORKDIR="$(mktemp -d 2>/dev/null || mktemp -d -t caleval)"
trap 'rm -rf "$WORKDIR"' EXIT INT TERM
FLOOR_TSV="$WORKDIR/floor.tsv"; : > "$FLOOR_TSV"
LINT_TSV="$WORKDIR/lint.tsv";   : > "$LINT_TSV"
DURAB_TSV="$WORKDIR/durab.tsv"; : > "$DURAB_TSV"

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
FNAME_TS="$(date -u +%Y%m%dT%H%M%SZ)"
SHORT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ -n "$(git status --porcelain 2>/dev/null || true)" ]; then GIT_DIRTY=1; else GIT_DIRTY=0; fi

# --- 1. floor: run every numbered gate, capture exit + trailing status token --------------------
run_floor() {
  local gate name out rc status pass=0 fail=0
  for gate in "$EVAL_REPO_ROOT"/tests/gates/[0-9][0-9]-*.sh; do
    [ -e "$gate" ] || continue
    name="$(basename "$gate")"
    set +e
    out="$(bash "$gate" 2>&1)"; rc=$?
    set -e
    status="$(printf '%s\n' "$out" | awk -F': ' '/^G[0-9]+ /{s=$2} END{split(s,a," "); print a[1]}')"
    [ -n "$status" ] || { if [ "$rc" -eq 0 ]; then status="ok"; else status="FAIL"; fi; }
    printf '%s\t%s\t%s\n' "$name" "$rc" "$status" >> "$FLOOR_TSV"
    if [ "$rc" -eq 0 ]; then pass=$((pass + 1)); else fail=$((fail + 1)); fi
  done
  FLOOR_PASS=$pass
  FLOOR_FAIL=$fail
}

# --- 2. scoped lint: drive each bundle's lint.sh over the scoped instance set -------------------
run_lint() {
  local feat files
  for feat in $EVAL_FEATURES; do
    if [ "$feat" = "general" ]; then
      bundle_lint_invoke general >> "$LINT_TSV"
      continue
    fi
    files="$(scope_files "$feat" "$SCOPE")"
    [ -n "$files" ] || continue
    printf '%s\n' "$files" | tr '\n' '\0' \
      | xargs -0 bash "skills/calibrate-${feat}/scripts/lint.sh" 2>/dev/null >> "$LINT_TSV" || true
  done
}

# --- 3. durability: adversarial re-introduction against shipped guards/gates (copies only) ------
run_durability() {
  local sandbox="$WORKDIR/sandbox" before after src copy payload rc run
  mkdir -p "$sandbox"
  before="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

  # (1) stripping `disable-model-invocation: true` makes G4's assertion report it missing.
  src="$(find skills -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null | sort | head -1)"
  if [ -n "$src" ] && [ -f "$src" ]; then
    copy="$sandbox/SKILL.md"
    grep -v -E '^disable-model-invocation:[[:space:]]*true' "$src" > "$copy" || true
    if gates_frontmatter "$copy" | grep -qE '^disable-model-invocation:[[:space:]]*true[[:space:]]*$'; then
      durab_emit "dmi-strip-detected" "dmi-absent" "dmi-present" "fail"
    else
      durab_emit "dmi-strip-detected" "dmi-absent" "dmi-absent" "pass"
    fi
  else
    durab_emit "dmi-strip-detected" "dmi-absent" "no-skill-found" "skip"
  fi

  # (2) calibrator writing outside its allow-list → exit 2 (guard self-disables without jq).
  if eval_have_jq; then
    payload="$(printf '{"agent_type":"calibration-calibrator","tool_input":{"file_path":"%s/tests/x.sh"}}' "$sandbox")"
    set +e
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$sandbox" bash "$EVAL_REPO_ROOT/hooks/calibrator-write-guard.sh" >/dev/null 2>&1
    rc=$?
    set -e
    if [ "$rc" -eq 2 ]; then durab_emit "calibrator-guard-blocks" "exit=2" "exit=$rc" "pass"
    else durab_emit "calibrator-guard-blocks" "exit=2" "exit=$rc" "fail"; fi
  else
    durab_emit "calibrator-guard-blocks" "exit=2" "no-jq" "skip"
  fi

  # (3) audit-only run: write outside the run folder → exit 2; inside → exit 0 (positive control).
  if eval_have_jq; then
    run="$sandbox/.claude/calibration/run-test"
    mkdir -p "$run"
    printf -- '---\nintent_source: audit-flow\n---\n' > "$run/plan.md"
    printf '%s' "$run" > "$sandbox/.claude/calibration/current"
    payload="$(printf '{"tool_input":{"file_path":"%s/CLAUDE.md"}}' "$sandbox")"
    set +e
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$sandbox" bash "$EVAL_REPO_ROOT/hooks/audit-write-guard.sh" >/dev/null 2>&1
    rc=$?
    set -e
    if [ "$rc" -eq 2 ]; then durab_emit "audit-guard-blocks" "exit=2" "exit=$rc" "pass"
    else durab_emit "audit-guard-blocks" "exit=2" "exit=$rc" "fail"; fi
    payload="$(printf '{"tool_input":{"file_path":"%s/plan.md"}}' "$run")"
    set +e
    printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$sandbox" bash "$EVAL_REPO_ROOT/hooks/audit-write-guard.sh" >/dev/null 2>&1
    rc=$?
    set -e
    if [ "$rc" -eq 0 ]; then durab_emit "audit-guard-allows-in-folder" "exit=0" "exit=$rc" "pass"
    else durab_emit "audit-guard-allows-in-folder" "exit=0" "exit=$rc" "fail"; fi
  else
    durab_emit "audit-guard-blocks" "exit=2" "no-jq" "skip"
    durab_emit "audit-guard-allows-in-folder" "exit=0" "no-jq" "skip"
  fi

  # meta: durability must not dirty the repo working tree.
  after="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$before" = "$after" ]; then durab_emit "repo-untouched" "no-change" "no-change" "pass"
  else durab_emit "repo-untouched" "no-change" "changed" "fail"; fi

  DURABILITY_RAN=1
}

run_floor
run_lint
[ "$WANT_DURABILITY" -eq 1 ] && run_durability

# --- human summary (always to stderr so stdout stays the artifact/path) -------------------------
_csev() { awk -F'\t' -v s="$1" '$3==s{n++} END{print n+0}' "$LINT_TSV"; }
{
  if [ "$FLOOR_FAIL" -eq 0 ]; then
    printf 'floor:       %d/%d gates green\n' "$FLOOR_PASS" "$((FLOOR_PASS + FLOOR_FAIL))"
  else
    printf 'floor:       ⚠ %d FAILING of %d gates\n' "$FLOOR_FAIL" "$((FLOOR_PASS + FLOOR_FAIL))"
  fi
  printf 'scope:       %s\n' "$SCOPE"
  printf 'findings:    CRITICAL %s · HIGH %s · MEDIUM %s · LOW %s · INFO %s   (total %s)\n' \
    "$(_csev CRITICAL)" "$(_csev HIGH)" "$(_csev MEDIUM)" "$(_csev LOW)" "$(_csev INFO)" \
    "$(awk 'END{print NR+0}' "$LINT_TSV")"
  if [ "$DURABILITY_RAN" -eq 1 ]; then
    dp="$(awk -F'\t' '$4=="pass"{p++} END{print p+0}' "$DURAB_TSV")"
    dn="$(awk 'END{print NR+0}' "$DURAB_TSV")"
    printf 'durability:  %s/%s checks pass\n' "$dp" "$dn"
  else
    printf 'durability:  (not run — pass --durability)\n'
  fi
} >&2

# --- emit + persist -----------------------------------------------------------------------------
if [ "$NO_WRITE" -eq 1 ]; then
  emit_snapshot
  exit 0
fi

SNAP_DIR="$EVAL_REPO_ROOT/tests/eval/snapshots"
mkdir -p "$SNAP_DIR"
SNAP_BASE="${FNAME_TS}-${SHORT_SHA}.json"
SNAP_PATH="$SNAP_DIR/$SNAP_BASE"
emit_snapshot > "$SNAP_PATH"
emit_ledger_line "snapshots/$SNAP_BASE" >> "$EVAL_REPO_ROOT/tests/eval/history.jsonl"

printf '%s\n' "tests/eval/snapshots/$SNAP_BASE"
printf '✓ snapshot written · ledger appended (tests/eval/history.jsonl)\n' >&2
