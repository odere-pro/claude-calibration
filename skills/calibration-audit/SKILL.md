---
name: calibration-audit
description: >-
  Read-only audit — runs the calibration planner-init and evaluator-baseline phases, prints the
  per-feature findings, then stops. No improvement plan, no approval gate, no edits. The same first
  half of /calibrate. Use this as a periodic health check or a CI gate when you only want to know
  "what's wrong" without applying anything. Persists baseline reports to .claude/calibration/<ts>/
  so a later /claude-calibration:calibration-diff can compare against them. Scope which plugins the
  audit covers with --plugins foo,bar (allow-list), --plugins -baz (block-list), or --plugins
  global|local; a persisted .claude/calibration/config.json sets the same default.
argument-hint: "[restart | --plugins <a,b|-c|global|local>]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Grep, Glob, Agent, TodoWrite, Write(.claude/calibration/**), Bash(git rev-parse:*), Bash(git status:*), Bash(date:*), Bash(ls:*), Bash(grep:*), Bash(mkdir:*)
---

```!
echo "=== calibration-audit preprocessing ==="
DOCS_DIR="$(cd "${CLAUDE_SKILL_DIR}/../../docs" 2>/dev/null && pwd || echo UNKNOWN)"
BUNDLES_DIR="$(cd "${CLAUDE_SKILL_DIR}/.." 2>/dev/null && pwd || echo UNKNOWN)"
echo "DOCS_DIR=$DOCS_DIR"
echo "BUNDLES_DIR=$BUNDLES_DIR"
echo "PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$(pwd)}"
echo "TIMESTAMP=$(date +%Y%m%d-%H%M%S)"
echo "NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "GIT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo not-a-git-repo)"
echo "GITIGNORE_HAS_CALIBRATION=$(grep -qs 'calibration' .gitignore && echo yes || echo no)"
PLUGIN_FILTER=""
[ "$BUNDLES_DIR" != "UNKNOWN" ] && [ -f "$BUNDLES_DIR/lib/resolve-plugin-filter.sh" ] && PLUGIN_FILTER="$(bash "$BUNDLES_DIR/lib/resolve-plugin-filter.sh" "$ARGUMENTS" "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || true)"
echo "PLUGIN_FILTER=$PLUGIN_FILTER"
echo "=== end preprocessing ==="
```

# calibration-audit — read-only baseline

You are the **audit-only flow**. Your job is to chain `calibration-planner` (init) and
`calibration-evaluator` (pass 1) — exactly the first two phases of `/calibrate` — and then **stop**.
No improvement plan; no approval gate; no calibrator. The user wants to know what's wrong, not fix
it.

The arguments are: `$ARGUMENTS` (`restart` starts a new audit run; `--plugins <val>` scopes which
plugins are audited — already normalised into `PLUGIN_FILTER` by the preprocessing block).

## Phases (subset of `/calibrate`)

1. **planner-init.** Create the run folder; write `plan.md` with intent `"audit (read-only)"`,
   `intent_source: audit-flow`.
2. **baseline-eval.** Evaluator pass 1 — write `eval-features-*.md`, `eval-interactions-*.md`,
   `eval-intent-flow-*.md`; set `last_phase_completed: baseline-eval`.
3. **Print the findings.** Read `plan.md` and the three eval reports; print:
   - The diagnostics ask (the four CLI outputs the user must paste for exact numbers).
   - Severity counts (C/H/M/L).
   - The top 5 highest-impact findings, one per line: `severity · scope · feature · signature · one-line detail`.
   - The path to the run folder so the user can read the full reports.
   - `→ Re-run /calibrate to plan fixes, or /claude-calibration:calibration-diff after manual edits.`

## Procedure

1. Resolve `DOCS_DIR`, `BUNDLES_DIR`, `PROJECT_DIR`, `TIMESTAMP`, `NOW_ISO`, `GIT_HEAD` from the
   preprocessing block. If `BUNDLES_DIR` is `UNKNOWN`, tell the evaluator to fall back to
   `Rubric dir: <DOCS_DIR>` only.
2. `$ARGUMENTS = restart` or no current audit folder → create `<PROJECT_DIR>/.claude/calibration/<TIMESTAMP>/`.
   Otherwise resume the latest audit folder (find via `ls -1dt .claude/calibration/*/ | head -1`).
3. Phase 1 — spawn `calibration-planner`:
   ```
   Agent(calibration-planner)
   Mode: init.
   Intent: "audit (read-only)".
   Intent source: audit-flow.
   Run folder: <abs>.
   Project dir: <PROJECT_DIR>.
   Rubric dir: <DOCS_DIR>.
   Bundles dir: <BUNDLES_DIR>.
   Git HEAD: <GIT_HEAD>.
   Started: <NOW_ISO>.
   Audit scope: user (~/.claude/) + project + enabled plugins.
   Plugin filter: <PLUGIN_FILTER>.
   ```
   On return: `✓ Audit run initialised: <run>/plan.md. → Next: baseline evaluation.`
4. Phase 2 — spawn `calibration-evaluator`:
   ```
   Agent(calibration-evaluator)
   Pass: 1 (baseline).
   Run folder: <abs>.
   Plan: <run>/plan.md.
   Rubric dir: <DOCS_DIR>.
   Bundles dir: <BUNDLES_DIR>.
   Project dir: <PROJECT_DIR>.
   Audit scope: user + project + plugins.
   Plugin filter: <PLUGIN_FILTER>.
   ```
   On return: print the counts + top 3 lines the evaluator returned.
5. **Read the reports yourself.** Open `<run>/eval-features-*.md`, `eval-interactions-*.md`, and
   `eval-intent-flow-*.md`. Compose the audit summary per the format above.
6. **Do not** spawn the planner in improve mode, do not present an approval gate, do not spawn the
   calibrator. The flow ends here.

## Hard rules

- You **never** invoke `Agent(calibration-calibrator)` and you **never** spawn
  `calibration-planner` with `Mode: improve`. If the user wants a plan or edits they re-run
  `/calibrate`.
- You only `Write` to the run folder (the planner and evaluator do that themselves; you do not).
- The shipped audit-only write-guard hook will exit 2 if anything tries to write outside the run
  folder during this flow — treat any such block as evidence of a bug and report it.
- If the planner or evaluator fail, surface the error one line and stop — do not continue silently.
