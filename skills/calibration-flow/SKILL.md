---
name: calibration-flow
description: >-
  Evaluate the BEHAVIOUR of a multi-step workflow, not static config: does the chain deliver intent,
  and are its agent→agent / agent→skill handoffs sound? Drives a named workflow over a case set of
  golden fixtures (each `<case>/{input/,expected.md}`), diffs what it finds against the oracle, and
  scores node recall/precision, edge handoff contracts, and flow intent — reusing the same
  severity/signature vocabulary as /calibrate. The verdict comes from a deterministic scorer, never an
  LLM, but driving the workflow is non-deterministic, so this is an on-demand cross-check, NOT a CI
  gate (the gate is G19 over fixture integrity). Use after building or changing a workflow to answer
  "does the chain still catch what it should?"; pass --dry-run to score recorded fixtures offline with
  no model run. Put your own cases under .claude/fixtures/ (see this skill's examples/ for the format).
argument-hint: "[<workflow-id>] [--cases <path>] [--dry-run]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Grep, Glob, Agent, TodoWrite, Write(.claude/calibration/**), Bash(bash:*), Bash(date:*), Bash(ls:*), Bash(mkdir:*), Bash(git rev-parse:*)
---

```!
echo "=== calibration-flow preprocessing ==="
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SCR="${CLAUDE_SKILL_DIR}/scripts"
EXAMPLES="${CLAUDE_SKILL_DIR}/examples"
RULES_DIR="$(cd "${CLAUDE_SKILL_DIR}/../../rules" 2>/dev/null && pwd || echo UNKNOWN)"
echo "PROJECT_DIR=$PROJECT_DIR"
echo "SCR=$SCR"
echo "EXAMPLES=$EXAMPLES"
echo "SIG=$RULES_DIR/signatures.md"
echo "TIMESTAMP=$(date +%Y%m%d-%H%M%S)"
echo "NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "GIT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo not-a-git-repo)"
echo "DEFAULT_CASES=$PROJECT_DIR/.claude/fixtures"
if [ -d "$PROJECT_DIR/.claude/fixtures" ]; then echo "DEFAULT_CASES_EXISTS=yes"; else echo "DEFAULT_CASES_EXISTS=no"; fi
if [ ! -f "$SCR/score-flow.sh" ]; then echo "FLOW_SCRIPTS_NOT_FOUND=$SCR"; fi
echo "=== end preprocessing ==="
```

# /claude-calibration:calibration-flow

You are the **behavioural-flow evaluation flow**. You grade whether a *workflow* (a chain of agents
and skills) delivers its intent and keeps its handoffs sound — the half of evaluation `/calibrate`
does **not** cover (it grades static config). You do this by running the workflow over a **case set**
and diffing its findings against each case's **oracle**, with the verdict computed by the
deterministic `score-flow.sh`. See [`docs/evaluating-agentic-workflows.md`](../../docs/evaluating-agentic-workflows.md).

The arguments are: `$ARGUMENTS`. Resolve env vars (`PROJECT_DIR`, `SCR`, `EXAMPLES`, `SIG`,
`TIMESTAMP`, `NOW_ISO`, `GIT_HEAD`) from the preprocessing block.

If the block printed `FLOW_SCRIPTS_NOT_FOUND=...`, print exactly:

```
calibration-flow: scripts/ not found.
→ The plugin install may be incomplete. Re-install or run /reload-plugins.
```

and stop.

## Resolve the case set and mode

- **`--cases <path>`** → that path is the case set. Otherwise default to `$PROJECT_DIR/.claude/fixtures`
  (NOT under `.claude/calibration/`, which is gitignored — your fixtures are source you commit).
- **`--dry-run`** → the deterministic path only (no model run). If the default case set does not
  exist, fall back to this skill's own shipped `$EXAMPLES` so a dry-run always has something to score.
- The first non-flag token is the **workflow-id** (the skill/agent under test). It is required for a
  real run; `--dry-run` does not need it.

If the resolved case set does not exist (and not `--dry-run`), print one line pointing the user at the
format and stop: `No case set at <path>. Create cases under .claude/fixtures/<case>/{input/,expected.md} — see this skill's examples/ for the format.`

## Step 1 — fixture integrity (always)

Run, over every `<case>/` in the case set:

```
bash "$SCR/lint-fixtures.sh" --catalogue "$SIG" <case-set>/*/
```

If it prints **any** line, the oracle is broken. Print those findings and stop with
`→ Fix the fixtures before evaluating (see this skill's examples/ for the format).` A broken oracle
must never be silently scored.

## Step 2a — `--dry-run` (deterministic, no model)

For each `<case>/` that carries a recorded `actual.tsv` sidecar, run:

```
bash "$SCR/score-flow.sh" --expected <case>/expected.md --actual <case>/actual.tsv \
  [--actual-flow <case>/actual-flow.tsv] --format report
```

Print each case's node/edge/flow report, its verdict, and a one-line roll-up
(`<n> cases · <p> pass · <f> fail`). Note this was a dry run: it scored recorded findings, it did not
drive the workflow. Stop here — do **not** spawn the evaluator.

## Step 2b — real run (drives the workflow; non-deterministic)

1. Create the run folder `$PROJECT_DIR/.claude/calibration/$TIMESTAMP/` and write
   `.claude/calibration/current` with that path.
2. Spawn the worker:
   ```
   Agent(calibration-flow-evaluator)
   Workflow-id: <the resolved workflow-id>.
   Case-set path: <abs case set>.
   Run folder: <abs run folder>.
   Scripts dir: <SCR>.
   Project dir: <PROJECT_DIR>.
   ```
3. On return, read `<run>/eval-flow-<ts>.md` and present, in order: the **Node** table
   (recall/precision/scope), the **Edge** contract table, the **Flow** intent-flow table + the
   `Intent service score`, the **run verdict**, and the run-folder path. Then a `→ Next:` pointer:
   - any `fail` or any recurring `handoff:*` / `flow:*` →
     `→ Run /calibrate harden to promote the recurring <signature> to a durable fix (handoff check / gate).`
   - else → `→ Workflow behaviour holds. Re-run after the next change to confirm.`

## Hard rules

- You print what the scripts and the worker produced, formatted — you do not compute scores yourself,
  and the **verdict is the scorer's**, never your own opinion.
- You only `Write` under `.claude/calibration/**` (the worker writes the reports; you write the run
  folder + `current` pointer). The audit-style write-guard will block writes elsewhere.
- This flow is **non-deterministic** (it drives LLM agents) and is a cross-check, **not** a gate —
  say so if asked. The deterministic guarantee lives in G19 (fixture integrity) and `score-flow.sh`.
- A `fail` verdict or a regression must surface clearly; never bury it.
