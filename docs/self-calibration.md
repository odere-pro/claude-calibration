[← README](README.md) · [Install](install.md) · [Usage](usage.md) · [Evaluators](claude-evaluators.md)

# Self-calibration — evaluating a setup against the rubric

How the plugin **evaluates a Claude Code setup** — what each entry point answers, what runs under
the hood when you start a full run, and how to point the whole machine **at the plugin's own files**
(the eat-our-own-dogfood loop). [`usage.md`](usage.md) is the task-by-task walkthrough; this page is
the "how the engine works" companion.

## The evaluation flows

Four read-first entry points, in increasing depth. All four are user-invocable and
`disable-model-invocation: true` (only you fire them; the model never auto-triggers a run).

| Flow                                            | Answers                                              | Writes config? | Cost           |
| ----------------------------------------------- | ---------------------------------------------------- | -------------- | -------------- |
| `/claude-calibration:calibration-doctor`        | _Is anything structurally broken?_ (parse, exec bit) | no             | ~seconds       |
| `/claude-calibration:calibration-audit`         | _What's wrong vs. the rubric?_ (read-only baseline)  | no             | one eval pass  |
| `/calibrate "<intent>"`                          | _Find it, plan it, fix it, re-check it._ (full loop) | yes, on approve| full 6 phases  |
| `/claude-calibration:calibration-diff`          | _Did my edits actually resolve the findings?_        | no             | one delta pass |

`doctor` is a structural smoke check, not a rubric audit; `audit` is the rubric audit with no edits;
`/calibrate` (the orchestrator) is the only entry point that changes files, and only after you
approve the plan. See
[`usage.md` → Convenience flows](usage.md#convenience-flows) for per-flow detail and
[`claude-evaluators.md`](claude-evaluators.md) for how these sit alongside the built-in evaluators
(`/doctor`, `/context`, `/skills`, `/mcp`).

## What runs under the hood

A full `/calibrate` run is a six-phase loop driven by a read-only Opus **orchestrator**
([`skills/calibrate/SKILL.md`](../skills/calibrate/SKILL.md)) that never edits config itself — it
chains subagents and minds the two human gates:

```
planner-init → baseline-eval → planner-improve → ⟨approval gate⟩
             → calibrate → delta-eval → final report → ⟨close gate⟩
```

Each phase leaves a `last_phase_completed` marker in `<run>/plan.md`, so a run survives `/clear` and
resumes from where it stopped.

### The workers

The chain runs on four worker subagents (the orchestrator spawns three; the evaluator fans the
fourth out ×9). Models are chosen for the job — Opus to reason about the plan, Haiku to grind through
enumeration in parallel, Sonnet for the careful middle work.

| Subagent                                                                    | Model  | Role                                                                                  | Writes                          |
| --------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------- | ------------------------------- |
| [`calibration-planner`](../agents/calibration-planner.md)                   | Opus   | `init`: create run folder + `plan.md`. `improve`: group findings, build the plan.     | `<run>/` only                   |
| [`calibration-evaluator`](../agents/calibration-evaluator.md)               | Sonnet | Audit conductor — fans out the feature workers, merges drafts, adds cross-feature reports. | `<run>/` eval reports        |
| [`calibration-feature-evaluator`](../agents/calibration-feature-evaluator.md) | Haiku  | ×9 in parallel, one per feature — runs the bundle's `enumerate.sh` + `lint.sh`, drafts findings. | `<run>/.drafts/` only      |
| [`calibration-calibrator`](../agents/calibration-calibrator.md)             | Sonnet | Applies approved rows through each bundle's templates/examples; re-lints to verify.   | config (allow-list) + `<run>/`  |

The 9 feature workers run as **one wall-clock pass** instead of nine sequential ones — token cost
scales with feature count, but you wait once. Only the calibrator ever touches config, and only
after the approval gate.

### Signatures and dispatch

Every finding is tagged with a stable signature — `<feature>:<short-name>`
(e.g. `claude-md:over-200`, `hook:matcher-bare-star`). Two path-scoped rule files carry the logic,
and load only when a run folder or a bundle directory is open (zero standing-context cost):

- [`rules/signatures.md`](../rules/signatures.md) — the canonical catalogue. **Names are stable
  across runs**: the planner's recurrence detector groups by signature, so a renamed signature
  silently breaks recurrence history.
- [`rules/dispatch.md`](../rules/dispatch.md) — the `signature → bundle` map. The planner stamps a
  `bundle:` on each plan row from it; the calibrator routes each approved row to that bundle's
  `SKILL.md` + `templates/`/`examples/`.

A pattern seen often enough (the recurrence threshold) is promoted from a one-off `kind: edit` fix
to a `kind: create` row — a new hook or rule that **prevents the whole class** from recurring. That
promotion is the plugin's highest-leverage move; see
[`usage.md` → recurrence flow](usage.md#the-recurrence--enforcement-creation-flow).

### Containment — the write-guards

Two `PreToolUse` hooks ([`hooks/hooks.json`](../hooks/hooks.json)) keep a run inside its lane. Both
exit `0` immediately when their condition doesn't hold, so they cost nothing except when they fire:

- [`hooks/calibrator-write-guard.sh`](../hooks/calibrator-write-guard.sh) — active only while the
  `calibration-calibrator` subagent is running. Blocks (`exit 2`) any write outside the calibrator's
  allow-list (`<project>/CLAUDE.md`, `.claude/**`, `.mcp.json`, `AGENTS.md`, `.gitignore`).
- [`hooks/audit-write-guard.sh`](../hooks/audit-write-guard.sh) — active only during a
  `calibration-audit` flow. Blocks any write outside the run folder, enforcing audit's read-only
  promise.

## Reading the verdict

Findings are scored `CRITICAL > HIGH > MEDIUM > LOW > INFO`. The baseline pass records counts per
severity; the delta pass re-audits and classifies each finding `resolved | partial | open | new`,
then prints before→after counts. The final report's severity table is the at-a-glance scorecard.

One caveat baked into every eval: the plugin **can't run the built-in diagnostics** (`/doctor`,
`/context all`, `/skills`, `/mcp` are CLI-handled, not agent-invocable). The first report section is
the "four diagnostics ask" — paste those four outputs and the next run swaps estimates for exact
numbers. For where each artifact lives and how to read it, see
[`usage.md` → Reading the run-folder files](usage.md#reading-the-run-folder-files).

## Auditing this plugin against itself

Because this repo _is_ a plugin (a `.claude-plugin/plugin.json` sits at the root), the same machine
can grade the plugin's own payload. Load it in dev mode and run a normal calibration:

```bash
cd /path/to/claude-calibration                  # this repo (or any other plugin repo)
claude --plugin-dir .                            # load the plugin in dev mode
```

In the session:

```text
/reload-plugins                                  # pick up any skill/agent edits made under --plugin-dir
/calibrate "audit this plugin's setup"           # or /claude-calibration:calibration-audit for read-only
```

When `.claude-plugin/plugin.json` exists, three bundles extend their enumeration to plugin-root
files (`calibrate-rules` → `<root>/rules/**`, `calibrate-hooks` → `<root>/hooks/*`,
`calibrate-plugins` recognises `rules/` as a payload component), and the **calibrator write-guard
extends its allow-list** so fixes can land in `skills/`, `agents/`, `rules/`, `hooks/`, and the
manifest. Non-plugin projects see none of this — the extension is gated on that one file existing.
[`usage.md` → Auditing this plugin itself](usage.md#auditing-this-plugin-itself) has the full
mechanics, phase-by-phase expectations, and the new signatures you might see (e.g.
`rule:plugin-shipped-no-paths`).

**When to reach for it:**

- **After adding a plugin component** — a new `rules/` file or hook script — to confirm it meets the
  rubric before you commit it.
- **Before bumping the manifest `version`** — a pre-release gate; clear HIGH/CRITICAL findings first.
- **As part of `/plugin-update`** — once the upstream docs shift a limit, realign the bundles, then
  self-audit to confirm the plugin's own files still match the now-current rubric.

## Limits

Self-calibration is **structural** — it reasons over config files against the rubric. It does not run
the built-in diagnostics, does not auto-apply user-scope (`~/.claude/**`) changes, and does not edit
anything outside the calibrator allow-list. Dynamic problems (a slow hook, a flaky MCP server, a
skill that never fires) need a transcript scan or live measurement and are out of scope. See
[`usage.md` → Limits](usage.md#limits) for the full list and the reasoning behind each.

## Sources

- The orchestrator and its phases — [`../skills/calibrate/SKILL.md`](../skills/calibrate/SKILL.md).
- The worker subagents — [`../agents/calibration-planner.md`](../agents/calibration-planner.md),
  [`../agents/calibration-evaluator.md`](../agents/calibration-evaluator.md),
  [`../agents/calibration-feature-evaluator.md`](../agents/calibration-feature-evaluator.md),
  [`../agents/calibration-calibrator.md`](../agents/calibration-calibrator.md).
- Signatures + routing — [`../rules/signatures.md`](../rules/signatures.md),
  [`../rules/dispatch.md`](../rules/dispatch.md).
- Containment — [`../hooks/hooks.json`](../hooks/hooks.json),
  [`../hooks/calibrator-write-guard.sh`](../hooks/calibrator-write-guard.sh),
  [`../hooks/audit-write-guard.sh`](../hooks/audit-write-guard.sh).
- Task-by-task walkthrough and the evaluator catalogue — [`usage.md`](usage.md),
  [`claude-evaluators.md`](claude-evaluators.md).
