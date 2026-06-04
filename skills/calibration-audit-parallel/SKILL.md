---
name: calibration-audit-parallel
description: >-
  Read-only calibration audit, parallelized with a headless `claude -p` fan-out. Runs the shipped
  scripts/run-parallel-audit.sh, which launches one `claude -p` process per feature (true OS-level
  parallelism), each acting as calibration-feature-evaluator, then a single synthesis pass merges the
  drafts into the baseline reports under .claude/calibration/<ts>/. Same result as
  /claude-calibration:calibration-audit, but the nine feature workers run as separate parallel CLI
  processes instead of one in-session fan-out — useful when you want maximum wall-clock parallelism or
  a script you can also run standalone in a terminal / CI. Read-only: no plan, no edits. Scope plugins
  with --plugins foo,bar (allow), --plugins -baz (block), or --plugins global|local.
argument-hint: "[--plugins <a,b|-c|global|local>]"
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Glob, Bash(bash *)
---

```!
echo "=== calibration-audit-parallel preprocessing ==="
SCRIPT="${CLAUDE_SKILL_DIR}/scripts/run-parallel-audit.sh"
echo "SCRIPT=$SCRIPT"
echo "SCRIPT_EXISTS=$([ -f "$SCRIPT" ] && echo yes || echo no)"
echo "PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$(pwd)}"
echo "CLAUDE_ON_PATH=$(command -v claude >/dev/null 2>&1 && echo yes || echo no)"
echo "ARGUMENTS=$ARGUMENTS"
echo "=== end preprocessing ==="
```

# calibration-audit-parallel — read-only baseline via headless `claude -p` fan-out

You are the **launcher** for the parallel calibration audit. This flow is read-only (no improvement
plan, no approval gate, no calibrator) — identical in scope to `/claude-calibration:calibration-audit`,
but the nine per-feature evaluators run as **separate parallel `claude -p` processes** driven by a
shipped shell script, rather than as one in-session subagent fan-out.

The arguments are `$ARGUMENTS` (`--plugins <val>` scopes which plugins are audited; passed straight
through to the script).

## Procedure

1. Read `SCRIPT`, `SCRIPT_EXISTS`, `PROJECT_DIR`, and `CLAUDE_ON_PATH` from the preprocessing block.
   - If `SCRIPT_EXISTS=no`, stop and tell the user the shipped script is missing from the plugin
     install (one line); point them at `/claude-calibration:calibration-audit` as the in-session
     fallback.
   - If `CLAUDE_ON_PATH=no`, stop and tell the user this flow needs the `claude` CLI on `PATH`
     (the workflow shells out to `claude -p`); suggest `/claude-calibration:calibration-audit`.
2. Run the script, forwarding the project dir and any `--plugins` argument. This launches the nine
   parallel `claude -p` workers, then the synthesis pass:

   ```
   Bash: bash "<SCRIPT>" "<PROJECT_DIR>" $ARGUMENTS
   ```

   It is a long-running, read-only command (nine concurrent headless `claude` processes, all
   writing only inside the new run folder). Let it finish; don't interrupt it.
3. **Present the result.** The script prints the run folder, the three report filenames, any worker
   errors, and the diagnostics ask. Relay that, then:
   - `Glob` the run folder for `eval-features-*.md` and `Read` it to surface the top 5 findings,
     one per line: `severity · scope · feature · signature · one-line detail`.
   - End with: `→ Re-run /calibrate to plan fixes, or /claude-calibration:calibration-diff after
     manual edits.`

## Hard rules

- You **never** call `Agent(calibration-calibrator)` and never plan or apply edits — this flow is
  read-only, same scope as `/claude-calibration:calibration-audit`.
- All file writes are performed by the script's child `claude -p` processes and land **inside** the
  run folder; the shipped `audit-write-guard.sh` hook (armed by `intent_source: audit-flow` in
  `plan.md`) blocks anything that tries to write outside it. Treat any such block as a bug.
- If the script exits non-zero, surface its error line and stop — do not silently fall back to a
  sequential in-session audit.
- This flow spends real tokens across nine concurrent `claude -p` invocations (haiku) plus one
  synthesis (sonnet). It is heavier than `/claude-calibration:calibration-audit`; only the wall-clock
  changes, not the rubric.
