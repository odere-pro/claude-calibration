---
name: calibration-track
description: >-
  Track whether calibration is actually improving your Claude Code setup across iterations. Takes a
  deterministic snapshot of the current config (a structural floor from calibration-doctor plus
  signature-keyed lint over all nine features), anchors a baseline to the last PR merged onto main,
  keeps a local gitignored history ledger, and prints an improvement/regression verdict vs that
  baseline AND vs the previous iteration. Unlike /calibrate's built-in before→after delta, this
  measure is deterministic and independent of the evaluator the calibrator optimizes against, so it
  can confirm real movement rather than restating the calibrator's own opinion. Measures config
  quality (does the setup get tighter/safer), not the runtime behaviour of the workflow. Use it after
  each calibration round, or after hand-edits, to answer "did that change actually help?"
argument-hint: "[--vs-baseline | --reset-baseline | --scope all]"
disable-model-invocation: true
model: haiku
allowed-tools: Read, Bash(bash:*), Bash(cat:*), Bash(date:*), Bash(ls:*)
---

```!
echo "=== calibration-track preprocessing ==="
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SCR="${CLAUDE_SKILL_DIR}/scripts"
echo "PROJECT_DIR=$PROJECT_DIR"
echo "NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ ! -f "$SCR/snapshot.sh" ]; then
  echo "TRACK_SCRIPTS_NOT_FOUND=$SCR"
else
  echo "--- baseline sync (config as of the last PR merged onto main) ---"
  bash "$SCR/snapshot.sh" "$PROJECT_DIR" --baseline 2>&1
  echo "--- iteration snapshot (current working tree) ---"
  bash "$SCR/snapshot.sh" "$PROJECT_DIR" 2>&1
  echo "--- compare: current vs base (last main merge) ---"
  bash "$SCR/compare.sh" "$PROJECT_DIR" --vs-baseline 2>&1; echo "VS_BASELINE_EXIT=$?"
  echo "--- compare: current vs previous iteration ---"
  bash "$SCR/compare.sh" "$PROJECT_DIR" 2>&1; echo "VS_PREVIOUS_EXIT=$?"
fi
echo "=== end preprocessing ==="
```

# /claude-calibration:calibration-track

You are the **iteration track**. The preprocessing block above has already taken a deterministic
snapshot of the setup, synced a baseline to the last PR merged onto `main`, and run two comparisons.
Your job is to **format and relay** those results and name the next step. Do not re-run the snapshot
sequence yourself (the block already did) and do not write any files — except the optional flag
handling below.

## What the snapshot measures (say this once, briefly, if asked)

A **deterministic** read of config quality: a structural floor (`broken / warn / ok` from
calibration-doctor) plus signature-keyed lint over all nine features. It is independent of
`/calibrate`'s built-in delta (which re-scores with the same evaluator the calibrator optimizes
against), so it can confirm *real* movement. It does **not** measure the runtime behaviour of a
workflow (e.g. whether a code-review setup catches more bugs) — that is out of scope.

## Output format

If the block reported `TRACK_SCRIPTS_NOT_FOUND=...`, print exactly:

```
calibration-track: scripts/ not found.
→ The plugin install may be incomplete. Re-install or run /reload-plugins.
```

and stop.

Otherwise present two short sections, then a verdict line and a `→ Next:` pointer:

1. **vs base (last main merge)** — relay the `current vs base` comparison: the severity
   before→after table, the floor line, and any non-`unchanged` signature rows. If that compare
   printed `no-baseline` / `no-base-ref`, say the base is unavailable (not a git repo, or no `main`
   lineage yet) and that only the iteration-over-iteration view applies.
2. **vs previous iteration** — relay the `current vs previous` comparison the same way. If it
   printed `need-two-iterations`, say this is the first tracked iteration and movement will show on
   the next run.

Keep the tables verbatim — they are already aligned. Don't invent numbers the block didn't print.

## The verdict + next step

Read the `verdict:` line and the `VS_BASELINE_EXIT` / `VS_PREVIOUS_EXIT` tokens. Choose the pointer:

- **Any `REGRESSION` (exit 1)** → `→ Regression since the base/last iteration — run /calibrate to plan fixes for the new or regressed findings.`
- **Else any `IMPROVED`** → `→ Improving. Keep iterating; re-run /claude-calibration:calibration-track after the next change to confirm it holds.`
- **Else (`no change of note`)** → `→ Flat vs base and previous. Run /calibrate to plan further improvements, or /claude-calibration:calibration-audit for a full rubric pass.`

A regression in *either* comparison wins (report it). Always note which comparison drove the verdict.

## Optional flags (only if `$ARGUMENTS` asks)

The arguments are: `$ARGUMENTS`. The standard path above needs none. Handle these only if present:

- `--reset-baseline` — the base may be stale or you want to re-anchor. Run
  `bash "${CLAUDE_SKILL_DIR}/scripts/snapshot.sh" "<PROJECT_DIR>" --baseline --reset-baseline`, then
  re-run `bash "${CLAUDE_SKILL_DIR}/scripts/compare.sh" "<PROJECT_DIR>" --vs-baseline` and use that.
- `--scope all` — widen lint from this project's `.claude/**` to everything enumerated (user config +
  installed-plugin cache; non-deterministic, diagnostic). Re-run
  `bash "${CLAUDE_SKILL_DIR}/scripts/snapshot.sh" "<PROJECT_DIR>" --scope all` then the two compares,
  and note the result is a diagnostic sweep, not the tracked project measure.
- `--vs-baseline` — show only the vs-base section; omit the vs-previous one.

## Hard rules

- You print only what the scripts emitted, formatted. The snapshot + compare already ran in the
  block; don't duplicate them on the standard path.
- You never write config files. The scripts persist snapshots under
  `.claude/calibration/track/` (gitignored) on their own — that is not a config edit.
- A regression verdict must surface clearly; never bury an `exit=1` comparison.
- If both comparisons are unresolvable (`no-baseline` and `need-two-iterations`), say so plainly:
  the first iteration is now recorded; run again after a change to see movement.
