#!/usr/bin/env bash
# run-parallel-audit.sh — read-only calibration audit via headless `claude -p` fan-out.
#
# This is the CLI-native parallel audit "workflow": it launches one `claude -p` process per
# feature in parallel (true OS-level concurrency), each acting as the canonical
# calibration-feature-evaluator agent for one feature, then runs a single synthesis pass
# (calibration-evaluator, Pass-1 steps 4–8) to merge the drafts into the baseline reports.
#
# Usage:
#   bash run-parallel-audit.sh [PROJECT_DIR] [--plugins <a,b|-c|global|local>]
#
# Runnable directly in a terminal, or via /claude-calibration:calibration-audit-parallel.
# Same output as /claude-calibration:calibration-audit: eval-*.md + plan.md under
# <PROJECT_DIR>/.claude/calibration/<ts>/. Read-only: every write lands inside the run folder.
set -euo pipefail

# --- locate ourselves inside the plugin (scripts/ -> bundle -> skills/ -> plugin root) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BUNDLES_DIR="${PLUGIN_DIR}/skills"
DOCS_DIR="${PLUGIN_DIR}/docs"
AGENTS_DIR="${PLUGIN_DIR}/agents"
FEAT_AGENT="${AGENTS_DIR}/calibration-feature-evaluator.md"
EVAL_AGENT="${AGENTS_DIR}/calibration-evaluator.md"

# --- args: optional PROJECT_DIR (a non-flag first arg), then passthrough flags ---
PROJECT_DIR="${PWD}"
if [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; then
  PROJECT_DIR="$1"
  shift
fi
ARGS_REST="$*"

# --- preconditions ---
if ! command -v claude >/dev/null 2>&1; then
  echo "ERROR: the 'claude' CLI is not on PATH — this workflow shells out to 'claude -p'." >&2
  exit 1
fi
for f in "${FEAT_AGENT}" "${EVAL_AGENT}"; do
  if [ ! -f "${f}" ]; then
    echo "ERROR: missing agent spec ${f} (is the plugin install complete?)." >&2
    exit 1
  fi
done

# --- resolve the plugin filter; export so each child's enumerate.sh is scoped ---
PLUGIN_FILTER=""
if [ -f "${BUNDLES_DIR}/lib/resolve-plugin-filter.sh" ]; then
  PLUGIN_FILTER="$(bash "${BUNDLES_DIR}/lib/resolve-plugin-filter.sh" "${ARGS_REST}" "${PROJECT_DIR}" 2>/dev/null || true)"
fi
export CALIBRATION_PLUGIN_FILTER="${PLUGIN_FILTER}"

# --- create the run folder + minimal plan.md (intent_source: audit-flow arms the write-guard) ---
TS="$(date +%Y%m%d-%H%M%S)"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
GIT_HEAD="$(git -C "${PROJECT_DIR}" rev-parse HEAD 2>/dev/null || echo not-a-git-repo)"
RUN="${PROJECT_DIR}/.claude/calibration/${TS}"
mkdir -p "${RUN}/.drafts"
printf '%s\n' "${RUN}" > "${PROJECT_DIR}/.claude/calibration/current"

cat > "${RUN}/plan.md" <<EOF
---
intent: "audit (read-only)"
intent_source: audit-flow
started: ${NOW_ISO}
git_head: ${GIT_HEAD}
plugin_filter: ${PLUGIN_FILTER}
last_phase_completed: planner-init
---

# Calibration run ${TS}

## Intent

audit (read-only)

## Contents

- [x] Phase 1 — planner-init
- [ ] Phase 2 — baseline-eval

## Artifacts

- Features report: (pending)
- Interactions report: (pending)
- Intent-flow report: (pending)
EOF

FEATURES=(claude-md rules settings skills subagents hooks mcp plugins general)

echo "Fan-out: ${#FEATURES[@]} parallel 'claude -p' feature workers (haiku) -> ${RUN}/.drafts/"
echo "Filter: ${PLUGIN_FILTER:-(all plugins)}"

# --- phase: parallel feature workers (one claude -p per feature) ---
pids=()
for feature in "${FEATURES[@]}"; do
  prompt="You are running ONE feature of a read-only calibration audit, headless. Read the agent
specification at ${FEAT_AGENT} and act as 'calibration-feature-evaluator' for these inputs:
Pass: 1 (baseline).
Feature: ${feature}.
Run folder: ${RUN}.
Bundles dir: ${BUNDLES_DIR}.
Rubric dir: ${DOCS_DIR}.
Project dir: ${PROJECT_DIR}.
Plugin filter: ${PLUGIN_FILTER}.
Draft path: ${RUN}/.drafts/feat-${feature}.md.
Write the draft file exactly as the spec describes, then reply with the one-line summary. Do not
write anywhere except the draft path."
  claude -p "${prompt}" \
    --model haiku \
    --permission-mode acceptEdits \
    --allowedTools "Read,Grep,Glob,Bash,Write" \
    --output-format json \
    > "${RUN}/.drafts/feat-${feature}.json" \
    2> "${RUN}/.drafts/feat-${feature}.err" &
  pids+=("$!")
done

# --- wait for all workers, tracking which features errored at the process level ---
failed=()
idx=0
for pid in "${pids[@]}"; do
  if ! wait "${pid}"; then
    failed+=("${FEATURES[$idx]}")
  fi
  idx=$((idx + 1))
done
if [ "${#failed[@]}" -gt 0 ]; then
  echo "WARN: feature workers exited non-zero: ${failed[*]} (synthesis will mark missing drafts)" >&2
fi

# --- phase: single synthesis pass (calibration-evaluator, steps 4–8) ---
echo "Synthesis: merging drafts + composing interactions/intent-flow ('claude -p', sonnet)..."
synth_prompt="Read the agent specification at ${EVAL_AGENT}. Acting as 'calibration-evaluator',
perform Pass-1 steps 4 through 8 ONLY — the per-feature baseline drafts already exist at
${RUN}/.drafts/feat-<feature>.md (canonical feature order: ${FEATURES[*]}). Do NOT spawn any
subagents and do NOT re-run the fan-out (steps 1–3 are already complete). Use the timestamp ${TS}
for the eval-*-<ts>.md filenames. Inputs: Run folder: ${RUN}. Plan: ${RUN}/plan.md. Bundles dir:
${BUNDLES_DIR}. Rubric dir: ${DOCS_DIR}. Project dir: ${PROJECT_DIR}. Merge into
eval-features-${TS}.md (a missing draft gets the 'feature evaluator failed' placeholder), compose
eval-interactions-${TS}.md and eval-intent-flow-${TS}.md, and update plan.md frontmatter and
Contents. Finish by printing your one-line baseline summary."
if ! claude -p "${synth_prompt}" \
  --model sonnet \
  --permission-mode acceptEdits \
  --allowedTools "Read,Grep,Glob,Bash,Write,Edit" \
  --output-format json \
  > "${RUN}/.synth.json" \
  2> "${RUN}/.synth.err"; then
  echo "ERROR: synthesis pass failed — see ${RUN}/.synth.err" >&2
  exit 1
fi

# --- deterministic cleanup of scratch (the run folder is later read by calibration-diff) ---
rm -rf "${RUN}/.drafts" "${RUN}/.synth.json" "${RUN}/.synth.err"

# --- report ---
echo ""
echo "Baseline audit complete."
echo "  Run folder: ${RUN}"
echo "  Reports:    eval-features-${TS}.md, eval-interactions-${TS}.md, eval-intent-flow-${TS}.md"
if [ "${#failed[@]}" -gt 0 ]; then
  echo "  Worker errors: ${failed[*]}"
fi
echo "  For exact numbers paste: /doctor, /context all, /skills (press t), /mcp"
echo "  -> Re-run /calibrate to plan fixes, or /claude-calibration:calibration-diff after manual edits."
