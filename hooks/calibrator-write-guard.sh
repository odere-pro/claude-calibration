#!/usr/bin/env bash
# calibrator-write-guard.sh — PreToolUse hook for Edit|Write|MultiEdit
#
# Scope: only enforces when the active subagent is `calibration-calibrator`.
# Effect: blocks (exit 2) any write whose target path is outside the calibrator's allow-list.
#
# Allow-list (in the active project):
#   - <PROJECT>/CLAUDE.md, CLAUDE.local.md
#   - <PROJECT>/.claude/**
#   - <PROJECT>/.mcp.json
#   - <PROJECT>/AGENTS.md
#   - <PROJECT>/.gitignore
#   - any file path explicitly listed in `<run>/plan.md`'s approved rows (frontmatter +
#     `## Improvement plan` table — best-effort grep, never rejects on parse failure).
#
# Stdin: hook input JSON (Claude Code passes this on PreToolUse).
# Exit codes:
#   0 — pass through (not the calibrator, or path is in allow-list, or hook can't decide safely)
#   2 — block; stderr is fed back to Claude as the error message
#
# Design note: this hook never falsely blocks. When in doubt it exits 0 — the prompt-discipline
# rule in agents/calibration-calibrator.md is still the primary defense; this is belt-and-braces.

set -u  # don't `set -e` — we want defensive fall-throughs

# Read stdin (the hook input JSON). If it's empty/unparseable, exit 0 (safe pass-through).
INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

# We need `jq` to parse the JSON cleanly. If it's missing, fall through — the prompt rule still
# applies and the user will see if the calibrator misbehaves.
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

AGENT_TYPE="$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)"

# Only enforce when the calibrator subagent is the actor.
if [ "$AGENT_TYPE" != "calibration-calibrator" ]; then
  exit 0
fi

# Pull the target path. Write uses .tool_input.file_path; Edit/MultiEdit may use file_path too.
TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"

# If we couldn't extract a path, fall through — we can't make a safe decision.
[ -z "$TARGET" ] && exit 0

# Normalise to an absolute path relative to CLAUDE_PROJECT_DIR if it's relative.
PROJECT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$TARGET" in
  /*) ABS="$TARGET" ;;
  ./*|[!./]*) ABS="$PROJECT/$TARGET" ;;
esac

# Strip a single `./` prefix.
ABS="${ABS#./}"

# Allow-list checks (string-prefix and exact match).
allowed=0
# project root files
for exact in \
  "$PROJECT/CLAUDE.md" \
  "$PROJECT/CLAUDE.local.md" \
  "$PROJECT/.mcp.json" \
  "$PROJECT/AGENTS.md" \
  "$PROJECT/.gitignore"; do
  if [ "$ABS" = "$exact" ]; then
    allowed=1
    break
  fi
done

# under .claude/ (recursive)
if [ $allowed -eq 0 ]; then
  case "$ABS" in
    "$PROJECT/.claude/"*) allowed=1 ;;
  esac
fi

# nested CLAUDE.md anywhere under project (monorepo-friendly)
if [ $allowed -eq 0 ]; then
  case "$ABS" in
    "$PROJECT/"*/CLAUDE.md|"$PROJECT/"*/CLAUDE.local.md) allowed=1 ;;
  esac
fi

# Plugin self-audit: when PROJECT is itself a plugin (.claude-plugin/plugin.json exists), the
# calibrator may also write to the plugin's standard component dirs at the plugin ROOT (not under
# .claude/). This is what lets `/calibrate "audit this plugin's setup"` actually apply fixes to
# plugin-root files. Non-plugin projects don't see this allow-list extension.
if [ $allowed -eq 0 ] && [ -f "$PROJECT/.claude-plugin/plugin.json" ]; then
  case "$ABS" in
    "$PROJECT/.claude-plugin/plugin.json") allowed=1 ;;
    "$PROJECT/skills/"*|"$PROJECT/agents/"*|"$PROJECT/rules/"*|"$PROJECT/hooks/"*) allowed=1 ;;
    "$PROJECT/commands/"*|"$PROJECT/bin/"*|"$PROJECT/monitors/"*) allowed=1 ;;
    "$PROJECT/.mcp.json"|"$PROJECT/.lsp.json") allowed=1 ;;
  esac
fi

# explicit plan-row paths (best-effort; never let a parse failure cause a block)
if [ $allowed -eq 0 ] && [ -f "$PROJECT/.claude/calibration/current" ]; then
  RUN="$(cat "$PROJECT/.claude/calibration/current" 2>/dev/null || true)"
  if [ -n "$RUN" ] && [ -f "$RUN/plan.md" ]; then
    # Crude grep for any line that contains the target path inside the plan. Avoids parsing the
    # table format directly. If the plan mentions the file at all, we trust the planner.
    if grep -Fq "$ABS" "$RUN/plan.md" 2>/dev/null; then
      allowed=1
    fi
  fi
fi

if [ $allowed -eq 1 ]; then
  exit 0
fi

# Outside the allow-list and the calibrator is active — block.
{
  printf '[calibrator-write-guard] BLOCKED — calibration-calibrator attempted to write outside its allow-list.\n\n'
  printf 'Target: %s\n' "$ABS"
  printf 'Project: %s\n\n' "$PROJECT"
  printf 'Allowed paths (project-scope only):\n'
  printf '  - <project>/CLAUDE.md, CLAUDE.local.md\n'
  printf '  - <project>/.claude/** (rules, settings, agents, skills, commands, hooks)\n'
  printf '  - <project>/.mcp.json\n'
  printf '  - <project>/AGENTS.md\n'
  printf '  - <project>/.gitignore\n'
  printf '  - any path explicitly listed in the current plan.md approved rows\n\n'
  printf "If this is a legitimate calibration row whose path isn't in plan.md, add it to the row's\n"
  printf "file column first. If this is a user-scope change (~/.claude/**), the calibrator should be\n"
  printf 'recommending it, not applying it.\n'
} >&2
exit 2
