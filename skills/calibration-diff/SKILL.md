---
name: calibration-diff
description: >-
  Compare the current Claude Code setup against the previous calibration run's baseline. Spawns only
  the evaluator (pass 2) — no planner, no calibrator, no edits. Useful between calibration runs (you
  manually edited a few files; what now shows resolved vs new?) and as a "did my changes hold up?"
  check after merging a PR. Writes eval-delta-*.md into the previous run folder and prints the
  before -> after counts. If no previous run exists, says so and points at /calibrate.
disable-model-invocation: true
model: opus
allowed-tools: Read, Grep, Glob, Agent, TodoWrite, Bash(ls:*), Bash(cat:*), Bash(date:*), Bash(git rev-parse:*)
---

```!
echo "=== calibration-diff preprocessing ==="
DOCS_DIR="$(cd "${CLAUDE_SKILL_DIR}/../../docs" 2>/dev/null && pwd || echo UNKNOWN)"
BUNDLES_DIR="$(cd "${CLAUDE_SKILL_DIR}/.." 2>/dev/null && pwd || echo UNKNOWN)"
echo "DOCS_DIR=$DOCS_DIR"
echo "BUNDLES_DIR=$BUNDLES_DIR"
echo "PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$(pwd)}"
echo "NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "GIT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo not-a-git-repo)"
if [ -f .claude/calibration/current ]; then
  CURRENT="$(cat .claude/calibration/current)"
  echo "CURRENT_RUN=$CURRENT"
else
  echo "CURRENT_RUN=(none)"
fi
echo "--- recent calibration runs (newest first) ---"
ls -1dt .claude/calibration/*/ 2>/dev/null | head -5 || echo "(none)"
echo "=== end preprocessing ==="
```

# calibration-diff — re-evaluate against the last baseline

You are the **diff-only flow**. You run the calibration **evaluator pass 2** against the previous
run's baseline reports and stop. No planner, no calibrator, no edits.

## What to do

1. Resolve `DOCS_DIR`, `BUNDLES_DIR`, `PROJECT_DIR` from the preprocessing block.
2. **Pick the run to diff against.** Default: the latest run folder with a complete `baseline_reports`
   list in `plan.md` (read it; the field is set when the evaluator finishes Pass 1). If the user
   passed a run identifier in `$ARGUMENTS` (e.g. a timestamp), use that one. If no run is found,
   print one line: `No prior calibration run found — run /calibrate first to establish a baseline.`
   and stop.
3. **Spawn the evaluator (Pass 2):**
   ```
   Agent(calibration-evaluator)
   Pass: 2 (delta).
   Run folder: <abs of the picked run>.
   Plan: <run>/plan.md.
   Baseline reports: <the names from plan.md baseline_reports>.
   Rubric dir: <DOCS_DIR>.
   Bundles dir: <BUNDLES_DIR>.
   Project dir: <PROJECT_DIR>.
   ```
   The evaluator will write `eval-delta-<ts>.md` into the run folder and update `plan.md`'s
   `last_evaluation` field.
4. **Print a short summary.** Read `plan.md`'s now-updated `last_evaluation` field; print:
   - `Diffing against: <run folder> (baseline taken <plan.started>).`
   - `Before: C<n> H<n> M<n> L<n>. After: C<n> H<n> M<n> L<n>.`
   - `Resolved <n> · partial <n> · open <n> · new <n>.`
   - `Delta report: <run>/eval-delta-<ts>.md.`
   - `→ Run /calibrate to plan fixes for the open + new findings.`

## Why diff-only

After a calibration run you may keep editing — hand-tuning a rule, adding a hook, deleting an
unused skill. This flow re-runs the evaluator against the baseline reports of that earlier run so
you can see "what changed since the last calibration" without re-spawning the planner or
calibrator. It's the cheapest way to confirm a fix held up.

## Hard rules

- You **never** invoke `calibration-planner` or `calibration-calibrator`. The evaluator's `Pass: 2`
  only updates `plan.md`'s `last_evaluation` and `last_phase_completed` (it sets `delta-eval`); it
  does not touch other state.
- You only `Write` indirectly through the evaluator subagent — no direct writes from you.
- If the picked run's `plan.md` is missing or unparseable, say so and stop; do not invent a baseline.
- If the user has applied changes by hand that the evaluator now sees in the same scope as a former
  finding, treat that as `resolved` — that's the point.
