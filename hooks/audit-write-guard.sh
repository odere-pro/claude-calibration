#!/usr/bin/env bash
# audit-write-guard.sh — PreToolUse hook for Edit|Write|MultiEdit
#
# Scope: only enforces when the current calibration run is an audit-only run
# (`intent_source: audit-flow` in plan.md — set by /claude-calibration:calibration-audit).
# Effect: during an audit-only run, every write must be inside the run folder. Anything outside
# is blocked (exit 2). This keeps the read-only contract of /claude-calibration:calibration-audit
# enforced at the tool-call layer.
#
# Stdin: hook input JSON (Claude Code passes this on PreToolUse).
# Exit codes:
#   0 — pass through (no audit run active, or write is inside the audit run folder, or hook can't
#       decide safely)
#   2 — block; stderr is fed back to Claude as the error message

set -u

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

PROJECT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Determine whether the current run is audit-only.
[ -f "$PROJECT/.claude/calibration/current" ] || exit 0
RUN="$(cat "$PROJECT/.claude/calibration/current" 2>/dev/null || true)"
[ -n "$RUN" ] && [ -f "$RUN/plan.md" ] || exit 0

# Cheap, robust check: did the audit flow create this run? Look for `intent_source: audit-flow`
# anywhere in the frontmatter. If we can't find it, no constraint — pass through.
if ! grep -qE '^intent_source:[[:space:]]*audit-flow' "$RUN/plan.md" 2>/dev/null; then
  exit 0
fi

# Extract the write target.
TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
[ -z "$TARGET" ] && exit 0

case "$TARGET" in
  /*) ABS="$TARGET" ;;
  *)  ABS="$PROJECT/$TARGET" ;;
esac
ABS="${ABS#./}"

# Allow only writes inside the audit run folder.
case "$ABS" in
  "$RUN"/*) exit 0 ;;
esac

# Outside the run folder during an audit-only run — block.
AGENT_TYPE="$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)"
{
  printf '[audit-write-guard] BLOCKED — write outside the audit run folder during an audit-only flow.\n\n'
  printf 'Audit run: %s\n' "$RUN"
  printf 'Active agent: %s\n' "${AGENT_TYPE:-(main thread)}"
  printf 'Target: %s\n\n' "$ABS"
  printf '/claude-calibration:calibration-audit is read-only: it runs the planner-init and evaluator-baseline\n'
  printf 'phases and stops. The only writes it should make are inside the run folder (%s/) — plan.md and\n' "$RUN"
  printf 'the three eval-*.md reports.\n\n'
  printf 'If you actually want to apply changes, run /calibrate instead.\n'
} >&2
exit 2
