---
name: calibration-audit-parallel
description: >-
  Read-only calibration audit, run as a Claude Workflow. Same result as
  /claude-calibration:calibration-audit (planner-init -> baseline-eval -> reports under
  .claude/calibration/<ts>/), but the nine per-feature evaluators are fanned out by a deterministic
  parallel() barrier at the workflow layer instead of being LLM-batched inside the evaluator. Use it
  as a periodic health check or CI gate when you want the baseline with guaranteed-parallel fan-out
  and a live progress tree (/workflows). Persists baseline reports so a later
  /claude-calibration:calibration-diff can compare. Scope plugins with --plugins foo,bar (allow),
  --plugins -baz (block), or --plugins global|local; a persisted .claude/calibration/config.json
  sets the same default.
argument-hint: "[restart | --plugins <a,b|-c|global|local>]"
disable-model-invocation: true
model: sonnet
allowed-tools: Workflow, Read, Glob, Bash(ls:*)
---

```!
echo "=== calibration-audit-parallel preprocessing ==="
DOCS_DIR="$(cd "${CLAUDE_SKILL_DIR}/../../docs" 2>/dev/null && pwd || echo UNKNOWN)"
BUNDLES_DIR="$(cd "${CLAUDE_SKILL_DIR}/.." 2>/dev/null && pwd || echo UNKNOWN)"
WORKFLOW_SCRIPT="${CLAUDE_SKILL_DIR}/workflow.mjs"
echo "DOCS_DIR=$DOCS_DIR"
echo "BUNDLES_DIR=$BUNDLES_DIR"
echo "WORKFLOW_SCRIPT=$WORKFLOW_SCRIPT"
echo "WORKFLOW_SCRIPT_EXISTS=$([ -f "$WORKFLOW_SCRIPT" ] && echo yes || echo no)"
echo "PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$(pwd)}"
case " $ARGUMENTS " in *" restart "*) echo "RESTART=true";; *) echo "RESTART=false";; esac
PLUGIN_FILTER=""
[ "$BUNDLES_DIR" != "UNKNOWN" ] && [ -f "$BUNDLES_DIR/lib/resolve-plugin-filter.sh" ] && PLUGIN_FILTER="$(bash "$BUNDLES_DIR/lib/resolve-plugin-filter.sh" "$ARGUMENTS" "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || true)"
echo "PLUGIN_FILTER=$PLUGIN_FILTER"
echo "=== end preprocessing ==="
```

# calibration-audit-parallel — read-only baseline, run as a Workflow

You are the **launcher** for the parallel calibration audit. Your only job is to start the shipped
`Workflow` script and report its result. You do **not** spawn the planner/evaluator yourself, and you
**never** apply edits — the workflow chains `calibration-planner` (init) and `calibration-evaluator`
(baseline) and stops, exactly like `/claude-calibration:calibration-audit`.

The arguments are `$ARGUMENTS` (`restart` starts a fresh run; `--plugins <val>` scopes which plugins
are audited — already normalised into `PLUGIN_FILTER` by the preprocessing block above).

## Procedure

1. Read `WORKFLOW_SCRIPT`, `WORKFLOW_SCRIPT_EXISTS`, `BUNDLES_DIR`, `DOCS_DIR`, `PROJECT_DIR`,
   `RESTART`, and `PLUGIN_FILTER` from the preprocessing block. If `WORKFLOW_SCRIPT_EXISTS=no`,
   stop and tell the user the shipped workflow script is missing from the plugin install (one line);
   suggest `/claude-calibration:calibration-audit` as the fallback. If `BUNDLES_DIR=UNKNOWN`, pass
   `bundlesDir`/`docsDir` as empty so the workflow falls back to its own discovery.
2. Launch the workflow by **path** (this is the opt-in: a user-invoked skill whose instructions tell
   you to call `Workflow`). Pass the resolved paths as `args` so the workflow does not have to
   re-discover them:

   ```
   Workflow({
     scriptPath: "<WORKFLOW_SCRIPT>",
     args: {
       projectDir:   "<PROJECT_DIR>",
       bundlesDir:   "<BUNDLES_DIR>",     // omit if UNKNOWN
       docsDir:      "<DOCS_DIR>",        // omit if UNKNOWN
       pluginFilter: "<PLUGIN_FILTER>",   // empty string = all plugins
       restart:      <RESTART>            // true | false
     }
   })
   ```

   The workflow runs four phases — **Resolve → Init → Fan-out (9 parallel feature evaluators) →
   Synthesize** — and returns `{ runFolder, pluginFilter, featuresDrafted, featuresFailed, summary }`.
3. **Print the audit summary** from the workflow's return value:
   - The diagnostics ask (the four CLI outputs the user must paste for exact numbers): `/doctor`,
     `/context all`, `/skills` (press `t` to sort by token cost), `/mcp`.
   - The `summary` line (baseline C/H/M/L counts + top findings) verbatim.
   - If `featuresFailed` is non-empty, note which features' workers errored.
   - The `runFolder` path so the user can open `eval-features-*.md`, `eval-interactions-*.md`, and
     `eval-intent-flow-*.md`.
   - `→ Re-run /calibrate to plan fixes, or /claude-calibration:calibration-diff after manual edits.`
4. Optionally, if `summary` is empty or truncated, `Glob` the run folder for `eval-features-*.md` and
   `Read` it to recover the top 5 findings (`severity · scope · feature · signature · one-line detail`).

## Hard rules

- You **never** call `Agent(calibration-calibrator)` and never run the planner in `improve` mode —
  this flow is read-only, identical in scope to `/claude-calibration:calibration-audit`.
- All file writes happen **inside** the run folder, performed by the workflow's subagents; the shipped
  `audit-write-guard.sh` hook (armed by `intent_source: audit-flow` in `plan.md`) blocks anything that
  tries to write outside it. Treat any such block as a bug and report it.
- If the `Workflow` run fails, surface the error in one line and stop — do not silently fall back to a
  sequential audit.
