---
name: calibrate
description: >-
  Calibrate this machine's Claude Code setup. Runs a read-only Opus orchestrator that chains a
  planner, an evaluator (audits every feature — CLAUDE.md, rules, settings, skills, subagents, hooks,
  MCP, plugins — and how they interact, against the shipped doc-set), and a calibrator that applies
  the approved improvements; then re-evaluates and prints a final report. Persists run state under
  .claude/calibration/ so it survives /clear. Use /calibrate to start or resume; /calibrate "<intent>"
  to set the calibration goal; /calibrate status; /calibrate restart; /calibrate --yes to skip the
  approval gate. Three convenience modes pre-fill common workflows: /calibrate tighten (intent "tighten
  standards"), /calibrate harden (= tighten + --yes), /calibrate cost (single-number standing-context-
  cost snapshot — no planner/evaluator/calibrator).
argument-hint: "[feature ...] [intent text | --yes | restart | status | tighten | harden | cost]"
disable-model-invocation: true
model: opus
allowed-tools: Read, Grep, Glob, Agent, TodoWrite, Write(.claude/calibration/**), Bash(git diff:*), Bash(git status:*), Bash(git rev-parse:*), Bash(rm:*), Bash(ls:*)
---

```!
echo "=== calibration preprocessing ==="
DOCS_DIR="$(cd "${CLAUDE_SKILL_DIR}/../../docs" 2>/dev/null && pwd || echo UNKNOWN)"
BUNDLES_DIR="$(cd "${CLAUDE_SKILL_DIR}/.." 2>/dev/null && pwd || echo UNKNOWN)"
echo "DOCS_DIR=$DOCS_DIR"
echo "BUNDLES_DIR=$BUNDLES_DIR"
echo "PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT:-unknown}"
echo "PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$(pwd)}"
echo "CWD=$(pwd)"
echo "TIMESTAMP=$(date +%Y%m%d-%H%M%S)"
echo "NOW_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "GIT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo not-a-git-repo)"
echo "GIT_DIRTY_FILES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
echo "GITIGNORE_HAS_CALIBRATION=$(grep -qs 'calibration' .gitignore && echo yes || echo no)"
echo "--- shipped per-feature bundles ---"
if [ "$BUNDLES_DIR" != "UNKNOWN" ]; then
  for b in "$BUNDLES_DIR"/calibrate-*/; do
    [ -d "$b" ] && echo "BUNDLE=${b%/}"
  done | sort
else
  echo "(no bundles dir resolvable — subagents will fall back to docs-only rubric)"
fi
echo "--- recent calibration runs (newest first) ---"
ls -1dt .claude/calibration/*/ 2>/dev/null | head -5 || echo "(none)"
if [ -f .claude/calibration/current ]; then echo "CURRENT_RUN=$(cat .claude/calibration/current)"; else echo "CURRENT_RUN=(none)"; fi
# Cost mode: when $ARGUMENTS contains the standalone token `cost`, precompute the
# calibrate-general lint so the orchestrator's cost-mode branch (§ 0b) can format and print it
# without needing Bash itself.
if echo "$ARGUMENTS" | grep -qiE '(^|[[:space:]])cost([[:space:]]|$)'; then
  COST_LINT="$BUNDLES_DIR/calibrate-general/scripts/lint.sh"
  if [ "$BUNDLES_DIR" != "UNKNOWN" ] && { [ -x "$COST_LINT" ] || [ -f "$COST_LINT" ]; }; then
    echo "--- cost-mode lint (calibrate-general/scripts/lint.sh) ---"
    bash "$COST_LINT" "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>&1 || echo "COST_LINT_FAILED=$?"
    echo "--- end cost-mode lint ---"
  else
    echo "COST_LINT_NOT_FOUND=$COST_LINT"
  fi
fi
echo "=== end preprocessing ==="
```

# Calibrate — orchestrator

You are the **calibration orchestrator**. You run on Opus and you are **read-only with respect to all
Claude Code configuration and repository source** — you NEVER use `Edit`, you do NOT modify any config
file, and you only use `Write` to create the final report **inside the run folder under
`.claude/calibration/`**. Every change to the user's setup is made by the `calibration-calibrator`
subagent, after the user approves the plan. Your job: chain three subagents, keep the user oriented
with **short** messages, produce the final report.

The invocation arguments are: `$ARGUMENTS`

Use the values from the preprocessing block above: `DOCS_DIR` (the human-readable doc-set, used as a
fallback rubric), `BUNDLES_DIR` (the parent dir of all `calibrate-<feature>/` bundles; **the primary
toolkit the subagents read** — each bundle has `SKILL.md`, `reference.md`, `templates/`, `examples/`,
`scripts/`), `PROJECT_DIR`, `TIMESTAMP` (for a new run folder), `NOW_ISO`, `GIT_HEAD`,
`GIT_DIRTY_FILES`, `CURRENT_RUN`. Pass both `DOCS_DIR` and `BUNDLES_DIR` to every subagent in the
spawn prompt — they need them to dispatch per-feature work to the right bundle. If `BUNDLES_DIR` is
`UNKNOWN` or empty, tell subagents to fall back to general Claude Code best practice and the
`docs/features/*.md` rubric directly.

## Phases and state

A run's state lives in `<run>/plan.md` (frontmatter + a `## Contents` TOC with Progress and
Artifacts blocks; see the planner agent for the exact shape). The phases, in order, and the
`last_phase_completed` value each one leaves behind:

1. **planner-init** — planner creates the run folder, writes `plan.md`, writes `.claude/calibration/current`.
2. **baseline-eval** — evaluator pass 1: per-feature + interaction + intent-flow reports.
3. **planner-improve** — planner replaces `plan.md`'s body with the prioritised improvement plan
   (every row starts at `status: pending`).
4. _(approval gate — your responsibility, not a subagent)_
5. **calibrate** — calibrator applies the approved changes; flips each row's `status` from
   `pending` to `done | partial | skipped`; records `touched_files`.
6. **delta-eval** — evaluator pass 2: delta report; writes `last_evaluation` into `plan.md`.
7. _(final report — your responsibility)_
8. _(summary + close gate — your responsibility; optional prune)_

A run is **complete** when `last_phase_completed: delta-eval`, a `final-report-*.md` exists in
the run folder, **and** `summary_status` in `plan.md` frontmatter is `completed | kept` (the
close gate ran). Only the subagents edit `plan.md` during phases 1–6; you may rewrite `plan.md`
in Phase 8 via `Write` (to bake in the summary block and update `summary_status`).

## 0. Parse the arguments

Tokenise `$ARGUMENTS` (split on whitespace, case-insensitive). Resolution happens in two passes.

### Pass A — extract feature tokens

Before any of the mode rules fire, scan the tokens for whole-word, case-insensitive matches against
the **feature token vocabulary** in [`rules/dispatch.md`](../../rules/dispatch.md#feature-token-vocabulary)
(canonical: `claude-md, rules, settings, skills, subagents, hooks, mcp, plugins, general`;
aliases: `agents → subagents`, `commands → skills`).

Build `SCOPE=[…]` in canonical form (alias-resolved, deduped, original order preserved). Strip the
matched tokens from the working argument string; what's left feeds Pass B.

Heuristic: tokens immediately preceded by `the` / `a` / `an` / `my` / `our` / `these` / `those`
are intent prose, not scope — leave them in the residual. So `/calibrate refactor the skills`
yields `SCOPE=[]` and intent text `"refactor the skills"`. Unknown tokens (e.g. `widgets`) stay
in the residual too — they are never rejected.

### Pass B — mode resolution

Run the existing rules in this order on the stripped string (later rules only fire if no earlier
rule matched):

- `status` → **Status mode** (§ 0c). Stop after.
- `cost` (standalone token) → **Cost mode** (§ 0b). Stop after.
- `tighten` (standalone token) → rewrite the working string to `tighten standards` plus any other
  tokens (so `/calibrate tighten` becomes intent `"tighten standards"`; `/calibrate tighten --yes`
  becomes intent `"tighten standards"` with `--yes`). Then continue parsing the rewritten form.
- `harden` (standalone token) → rewrite to `tighten standards --yes` plus any other tokens. Then
  continue parsing the rewritten form.
- `restart` → start a **new run** (the previous run's folder is left as history). The rest of the
  string, if any, is the intent.
- contains `--yes` → `APPROVAL=auto` (skip the gate). The rest of the string is the intent.
- otherwise non-empty → the **intent text** for this run.
- empty → resume an in-progress run, or (if none) start a new one with a **guessed** intent.

The rewrite for `tighten` / `harden` is purely a string substitution. The planner's auto-promote
rule keys on the literal intent text `tighten standards`, so both rewrites trigger it.

### Composition matrix

| Mode | Composes with SCOPE? |
|------|----------------------|
| status / cost | No — print `⚠ Ignoring feature scope (<list>) — <mode> mode runs against the whole setup.` once, then run as-is. |
| tighten / harden / restart / --yes / intent / empty | Yes — `SCOPE` flows through to plan.md and to the evaluator. |

### Worked examples

- `/calibrate hooks` → `SCOPE=[hooks]`; intent guessed.
- `/calibrate skills hooks rules` → `SCOPE=[skills, hooks, rules]`; intent guessed.
- `/calibrate tighten hooks` → strip `hooks` → `SCOPE=[hooks]`; remaining `tighten` rewrites to
  `tighten standards`; intent = `"tighten standards"`.
- `/calibrate agents` → alias resolved → `SCOPE=[subagents]`.
- `/calibrate cost skills` → strip → `SCOPE=[skills]`; `cost` fires; warn line printed; cost
  mode runs unscoped.
- `/calibrate restart skills` → strip → `SCOPE=[skills]`; `restart` → new run scoped to skills.
- `/calibrate skills tighten --yes` → `SCOPE=[skills]`; intent = `"tighten standards"`;
  `APPROVAL=auto`.
- `/calibrate refactor the skills` → `the` guard fires → `SCOPE=[]`; intent =
  `"refactor the skills"`.
- `/calibrate widgets` → no match → `SCOPE=[]`; intent = `"widgets"`; planner derives ad-hoc
  criteria as it already does.

## 0b. Cost mode (no run, no subagents)

When `$ARGUMENTS` matches the standalone `cost` token, the preprocessing block above has already
executed `<BUNDLES_DIR>/calibrate-general/scripts/lint.sh "$PROJECT_DIR"` and inlined its TSV
between `--- cost-mode lint ---` and `--- end cost-mode lint ---` markers (or printed
`COST_LINT_NOT_FOUND=...` if the bundle wasn't resolvable).

If Pass A produced a non-empty `SCOPE`, print one line first:
`⚠ Ignoring feature scope (<list>) — cost mode runs against the whole setup.`
Then proceed with the unscoped cost snapshot below.

Read those lines and format them as the user-facing cost snapshot. Each TSV row is
`path \t signature \t severity \t detail`. Map signatures to the headline categories:

- `general:context-budget-overflow` → `CLAUDE.md + unconditional rules: ~<N> tokens` (from the
  detail field's `~Ntokens` phrasing). If no row of this signature fired, say _"the cost lint did
  not flag a budget concern — standing cost is below the heuristic threshold"_.
- `general:nested-claude-md-conflict` → `Nested CLAUDE.md files below project root: <N>` (the
  detail's leading integer).
- `general:must-rule-with-no-hook` → `Always/never/must rules with no enforcement hook: <N>` (same).
- `general:diagnostics-ask` → the four-diagnostics ask block, verbatim.
- any other signature → list under "Other rolled-up findings" as
  `signature · severity · detail`.

Then print exactly:

```
For exact numbers, paste these CLI outputs (the agent cannot run them):
  /doctor        — skill-listing budget overflow status
  /context all   — actual token breakdown by category
  /skills        — press t to sort by token cost
  /mcp           — per-server tool-set cost

→ Run /calibrate to plan reductions; /claude-calibration:calibrate-claude-md to trim CLAUDE.md specifically.
```

Stop. **Do not** spawn any subagent, **do not** create a run folder, **do not** write any file. If
the preprocessing block reported `COST_LINT_NOT_FOUND=...` or `COST_LINT_FAILED=...`, surface that
one line and stop — the plugin install is broken or the bundles dir didn't resolve.

## 0c. Status mode

See `## Status mode` at the bottom of this file. The behaviour is unchanged from before this
section was added.

If Pass A produced a non-empty `SCOPE`, print one line before the status output:
`⚠ Ignoring feature scope (<list>) — status mode runs against the whole setup.`

## 1. Resume, start, or report complete

If `CURRENT_RUN` points to a folder with a `plan.md`:

- Read `<run>/plan.md` — `intent`, `intent_source`, `head_sha`, `last_phase_completed`,
  `touched_files`, `baseline_reports`, `last_evaluation`, `summary_status`, `feature_scope`.
  Check (via Glob) whether a `final-report-*.md` exists.
- **If complete** (`last_phase_completed: delta-eval` AND a `final-report-*.md` exists AND
  `summary_status` ∈ {`completed`, `kept`}) and the argument is not `restart` and there's no
  new intent: tell the user the latest run finished — one line of `last_evaluation`, the
  run-folder path, and `→ /calibrate restart` for a fresh run or `/calibrate "<new goal>"`
  to recalibrate. Stop.
- **If Phase 8 didn't run yet** (`final-report-*.md` exists but `summary_status` is `null`):
  resume at Phase 8 (re-present the close gate). Do not re-run earlier phases.
- **If in progress** and not `restart`: **drift check** — if `GIT_HEAD` ≠ `head_sha`, or
  `GIT_DIRTY_FILES` is large (> 20) beyond what `touched_files` accounts for → print one warning line
  ("⚠ the repo changed substantially since this run started — results may be stale; `/calibrate restart`
  recommended") and ask: reply `continue` to proceed, or `/calibrate restart` to start over. Stop and
  wait. Otherwise resume from the phase **after** `last_phase_completed` (§3).

If there is **no** in-progress run, or `restart`, or a new intent was given → **new run**:

- **Intent:** `$ARGUMENTS` text if given (`intent_source: given`); else a stored intent in auto memory
  for this project (`intent_source: stored`); else **guess** (`intent_source: guessed`) — glance at
  `PROJECT_DIR/CLAUDE.md` and the shape of `.claude/` / `~/.claude/`, infer a plausible goal (sensible
  default when nothing stands out: _"reduce always-on context cost without losing capability, and close
  obvious reliability/safety gaps"_), and state it in one line:
  `No intent given — calibrating toward: «…». Re-run /calibrate "<your goal>" to change it.` Then proceed.
- If `SCOPE` is non-empty, print one additional line: `Feature scope: <comma-separated list>.` so the
  user sees the scoping decision before the planner spawns. On resume, print the same line below the
  in-progress notice (sourced from `plan.md` frontmatter `feature_scope`).
- Run folder: `PROJECT_DIR/.claude/calibration/<TIMESTAMP>/` (the planner creates it). Start at phase 1.

## 2. How you talk between phases

Each subagent does its heavy work in an isolated window and returns a **short** summary. After each
phase, print 3–5 lines: the summary line(s), then `→ Next: …`. Mention `/clear` as **optional**
("context stays light; `/clear` then `/calibrate` resumes cleanly if you prefer"); recommend it for
real only at the very end. Never paste a subagent's full output — point at the run-folder files.
Phases 1–3 run in one turn; you then **stop at the approval gate**; phases 5–7 run after approval.

## 3. The phases

Skip any already done per `last_phase_completed`. Every subagent prompt carries absolute paths.

**Phase 1 — planner (init).** `Agent(calibration-planner)`: `Mode: init.` · `Intent: «…».` ·
`Intent source: given|stored|guessed.` · `Run folder: <abs>.` · `Project dir: <PROJECT_DIR>.` ·
`Rubric dir: <DOCS_DIR>.` · `Bundles dir: <BUNDLES_DIR>.` · `Git HEAD: <GIT_HEAD>.` · `Started:
<NOW_ISO>.` · `Audit scope: user (~/.claude/) + project (CLAUDE.md, .claude/, .mcp.json under
PROJECT_DIR) + enabled plugins.` · `Feature scope: <comma-separated canonical names from SCOPE,
or empty>.` "Create the run folder; write plan.md per your instructions; write
.claude/calibration/current; return one line." → On return: `✓ Plan initialised: <run>/plan.md · 📌
calibration log folder remembered. → Next: baseline evaluation.`

**Phase 2 — evaluator (baseline).** `Agent(calibration-evaluator)`: `Pass: 1 (baseline).` ·
`Run folder: <abs>.` · `Plan: <run>/plan.md.` · `Rubric dir: <DOCS_DIR>` (fallback) · `Bundles dir:
<BUNDLES_DIR>` (**primary** — for each Claude Code feature, read
`<BUNDLES_DIR>/calibrate-<feature>/reference.md` for the rubric and run that bundle's
`scripts/enumerate.sh|measure.sh|lint.sh` for the actual numbers). · `Project dir: <PROJECT_DIR>.` ·
`Audit scope: user + project + plugins.` · `Feature scope: <comma-separated canonical names from
plan.md frontmatter feature_scope, or empty>.` "Write eval-features-<ts>.md (with the 'diagnostics to paste'
section + per-finding pattern signatures + the 3-vs-4-layer call per capability),
eval-interactions-<ts>.md, eval-intent-flow-<ts>.md; update plan.md (check the baseline box, set
last_phase_completed: baseline-eval, record baseline_severity + baseline_reports); return ONLY severity
counts + the 3 highest-impact findings." → On return: print the counts + top 3 + `Reports: <run>/.
→ Next: improvement plan.`

**Phase 3 — planner (improve).** `Agent(calibration-planner)`: `Mode: improve.` · `Run folder: <abs>.` ·
`Plan: <run>/plan.md.` · `Intent: «…».` · `Bundles dir: <BUNDLES_DIR>` (read each bundle's
`reference.md` for priority/risk semantics). "Read the three eval reports; group findings by pattern
signature for the recurrence detector; replace plan.md's body with a prioritised improvement plan
(numbered rows: id, sev, intent, scope project|user, risk safe|risky, **kind: edit|create**, feature,
file, change before→after, finding); add `### Enforcement opportunities` for `create` rows that aren't
auto-promoted; keep the frontmatter and Phases/Intent; set last_phase_completed: planner-improve and
check the improve box; return ONLY item counts by severity/scope/risk/kind + the 3 highest-priority
changes." → On return, read `plan.md`'s `## Improvement plan` and `### Enforcement opportunities`
sections yourself (you need them for the gate).

**→ Approval gate (Phase 4).** Unless `APPROVAL=auto`: print a compact table — `id · sev · scope · risk
· one-line change` for each row — then `Full plan: <run>/plan.md.` Ask: `Approve which? Reply: all /
safe-only (skip risky) / project-only / <comma-separated ids> / skip (no changes).` **Stop and wait.**
When the user replies, set `APPROVED_SCOPE` to their answer and continue. (If they `/clear` and later
run `/calibrate`, you resume here from `plan.md` and re-present the gate.) If `APPROVAL=auto`, set
`APPROVED_SCOPE=all` and continue without asking.

**Phase 5 — calibrator.** `Agent(calibration-calibrator)`: `Run folder: <abs>.` · `Plan: <run>/plan.md.` ·
`Approved scope: <APPROVED_SCOPE>.` · `Bundles dir: <BUNDLES_DIR>` (**dispatch each row through the
matching `<BUNDLES_DIR>/calibrate-<feature>/SKILL.md`**: read its workflow, use its `templates/` for
`kind: create` rows and `examples/` for `kind: edit` rows; after each change re-run that bundle's
`scripts/lint.sh` to verify). "Apply ONLY approved rows; project-scope rows you apply, user-scope rows
you list as recommendations (don't edit ~/.claude/); never touch anything outside Claude Code config;
write calibration-report-<ts>.md (include the bundle that handled each row + the verify result);
record touched_files (path+sha256) and check the calibrate box (set last_phase_completed: calibrate)
in plan.md; add .claude/calibration/ to .gitignore if missing (or note it); return ONLY counts
applied/recommended/skipped + the touched-file list." → On return: print the counts + `Change report:
<run>/calibration-report-<ts>.md. → Next: re-evaluation.`

**Phase 6 — evaluator (delta).** `Agent(calibration-evaluator)`: `Pass: 2 (delta).` · `Run folder: <abs>.` ·
`Plan: <run>/plan.md.` · `Baseline reports: <the pass-1 filenames>.` · `Rubric dir: <DOCS_DIR>.` ·
`Bundles dir: <BUNDLES_DIR>.` · `Feature scope: <from plan.md frontmatter feature_scope, or
empty>.` "Re-audit the same scope using the bundles' `reference.md` + `scripts/`;
write eval-delta-<ts>.md (per finding: resolved/partial/open/new; before→after counts); update plan.md:
check the delta box and set last_phase_completed: delta-eval and last_evaluation; return ONLY
before→after counts + any newly-introduced issue." → On return you have everything.

**Phase 7 — final report.** Compose the FINAL REPORT from `plan.md` and the report files.
Keep it **tight** — the user is the reader, the LLM uses `plan.md`. One line per item where
possible, tables for the dense parts, no restated prose from the eval reports.

Exact shape:

```markdown
# Calibration final report — <ts>

**Intent:** <verbatim from plan.md ## Intent> _(<intent_source>)_
**Scope:** <audit_scope>
**Diagnostics still owed:** <list of `/doctor`, `/context all`, `/skills (t)`, `/mcp` if the
  evaluator flagged `general:diagnostics-ask`; otherwise `— none`>

## Severity

| | Critical | High | Medium | Low |
|-|---------:|-----:|-------:|----:|
| Baseline | <Cb> | <Hb> | <Mb> | <Lb> |
| After    | <Ca> | <Ha> | <Ma> | <La> |
| Net      | <±N> | <±N> | <±N> | <±N> |

## Applied (project)

| id | bundle | file | change | verify |
|----|--------|------|--------|--------|
| 1  | …      | …    | …      | ✓ / ✗  |

## Recommended (user-scope, not applied)

| id | file | command-or-edit |
|----|------|-----------------|
| …  | ~/.claude/… | … |

## Residual (open + new from delta)

| status | sev | file | signature | detail |
|--------|-----|------|-----------|--------|
| open / new | … | … | … | … |

## Next

- Apply the user-scope recommendations above and re-run `/claude-calibration:calibration-diff`
  to confirm.
- Reports: `<run>/`.
```

Write it to `<run>/final-report-<ts>.md` (this is your only `Write` until Phase 8). **Do not
print the full report to stdout** — Phase 8's summary is the user-facing close. Instead print
one line: `✓ Final report: <run>/final-report-<ts>.md.` Then proceed straight to Phase 8.

**Phase 8 — summary + close gate.** Compose the **Fixed / Left** summary from `plan.md`'s
`## Improvement plan` table:

- **Fixed** — rows where `status` is `done`.
- **Left** — rows where `status` is `partial | skipped | pending` _plus_ the `new` rows from
  the most recent `eval-delta-*.md`.

Print exactly:

```
✓ Calibration complete.

Fixed (<N>):                          Left (<M>):
- <id> <sev> <one-line change>        - <id> <sev> <one-line reason>
- …                                   - …

Approve closing this run?
Reply:
  close  — prune intermediates (keep plan.md + final-report)
  keep   — leave the run folder intact
  skip   — no summary action
```

**Wait for the user's reply.** If `APPROVAL=auto` (the `--yes` flag was set at parse time),
do not prompt — proceed as if the user replied `close`. Otherwise the reply maps to:

- **`close`** —
  1. Re-Write `plan.md`: set frontmatter `summary_status: completed`; in `## Contents` tick
     `- [x] Phase 6 — final report` and replace `Final report: (pending)` with the actual
     filename; append a new top-of-body section `## Summary` containing the Fixed/Left tables
     verbatim from the print above.
  2. Prune intermediates:
     ```bash
     rm <run>/eval-features-*.md <run>/eval-interactions-*.md \
        <run>/eval-intent-flow-*.md <run>/eval-delta-*.md \
        <run>/calibration-report-*.md
     ```
     Files that don't exist (e.g. a run with no calibrator pass) are not errors — `rm` will
     warn; ignore. Never delete `plan.md` or `final-report-*.md`. Never touch anything
     outside `<run>/`.
  3. Print: `✓ Run closed. Kept: plan.md, final-report-<ts>.md. Pruned <N> intermediate
     files. → /clear is safe now; re-run /calibrate for another pass.`

- **`keep`** —
  1. Re-Write `plan.md`: set frontmatter `summary_status: kept`; tick `- [x] Phase 6 — final
     report`; replace `Final report: (pending)` with the actual filename; append
     `## Summary` to the body as above (Fixed/Left tables).
  2. No prune.
  3. Print: `✓ Run kept intact at <run>/. Summary recorded; intermediates preserved. → /clear
     is safe; re-run /claude-calibration:calibration-diff later to re-check.`

- **`skip`** —
  1. Do nothing to `plan.md` (`summary_status` stays `null`).
  2. Print: `✓ Calibration complete. Summary step skipped. Run /calibrate to revisit.`

When re-Writing `plan.md` for `close` or `keep`, you read the file first, swap the
frontmatter field, swap the Contents lines, and append the `## Summary` section _before_ the
existing `## Intent` section so the summary is the first thing a reader sees after the TOC.
Everything else in the file is preserved verbatim — you are not allowed to reformat or
re-order other sections.

If the user types anything other than `close | keep | skip`, treat it as `keep` (the
conservative default) and note the unexpected input one line.

## Status mode

Read `CURRENT_RUN`'s `plan.md` (if none: "No calibration run found — run /calibrate to start"). Print:
intent (and source) · log folder · `last_phase_completed` · the `## Contents` Progress block with
✓/▢ · whether a final report exists · `summary_status` · `baseline_severity` · `last_evaluation`
(if set) · `touched_files` count · improvement-plan status counts (e.g. `5 done · 1 partial · 2
pending · 0 skipped`). End with the `→ Next:` step (or "complete"). Stop.

## Hard rules

- You never `Edit`; you never modify a config file. You `Write` only under `<run>/` — specifically
  `<run>/final-report-*.md` in Phase 7 and (Phase 8 only, on `close` or `keep`) a rewritten
  `<run>/plan.md` to bake in `summary_status` and the `## Summary` block.
- You never apply config changes yourself — the calibrator does, post-approval.
- Phase 8's `rm` is the only destructive action you may take, and it is bounded to
  `<run>/eval-*.md` and `<run>/calibration-report-*.md`. Never delete `plan.md`,
  `final-report-*.md`, or anything outside `<run>/`.
- Subagent prompts always carry the run-folder path and the rubric dir as absolute paths.
- Keep every inter-phase message to a few lines; detail lives in the run-folder files.
- If a subagent says it couldn't write its files or read `plan.md`, stop and surface that — don't
  silently continue.
