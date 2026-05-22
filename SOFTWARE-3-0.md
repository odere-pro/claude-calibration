# Software 3.0 — why `claude-calibration` is shaped this way

A short design thesis. It explains the constraint every architectural decision in this repo flows
from, and why a plugin made of Markdown and a few Bash scripts is a *Software 3.0* artifact rather
than an under-built one.

## The three eras

- **Software 1.0** — programs are explicit code: humans write the instructions a CPU runs.
- **Software 2.0** — programs are learned weights: the behaviour is fit from data, not written.
- **Software 3.0** — programs are *prompts*: natural-language instructions steer a model that is the
  runtime. The "source" is prose, the "compiler" is the LLM.

`claude-calibration` lives in 3.0, and it audits other 3.0 programs.

## The plugin is itself a 3.0 program

Nothing here compiles. The payload is prose that an LLM executes:

- `skills/**/SKILL.md` — the orchestrator, dispatcher, flows, and nine per-feature bundles are
  written instructions, not code.
- `agents/*.md` — the planner, evaluator, calibrator, and feature-evaluator are role prompts.
- `rules/{signatures,dispatch}.md` — the catalogue and routing logic are tables Claude reads.
- `docs/**` — the grading rubric the evaluator scores against is just documentation.

The Bash that exists (`scripts/lint.sh`, `scripts/enumerate.sh`, the write-guard hooks) is
deliberately *thin*: it does the deterministic, countable work (enumerate files, tally findings,
block a write) and hands the judgement back to the model. That split is the thesis in miniature.

## It is agent-operable

A 3.0 program has to be runnable *by an agent*, not just readable by a human. `/calibrate` is a chain
of agents — `calibration-planner` → `calibration-evaluator` (which fans out to nine haiku
`calibration-feature-evaluator` workers) → `calibration-calibrator` → a delta re-evaluation. State
persists in `.claude/calibration/<run>/plan.md`, so a run survives `/clear` and resumes where it
stopped. The contracts between stages — the pattern-signature strings, the `plan.md` row format, the
TSV that `lint.sh` emits — are stable enough that each agent can pick up the previous one's output
without a human in the loop.

## It calibrates other 3.0 setups

The thing being audited is *also* prose-as-program: someone's `CLAUDE.md`, their rules, their skills
and subagents. The evaluator reads those prompt-programs and scores them against the doc-grounded
rubric — does this skill route well, does this subagent over-inherit tools, does this CLAUDE.md state
a "must" that nothing enforces. It is a 3.0 program reviewing 3.0 programs.

## The core move: the 3.0 → 2.0 / 1.0 hand-off

Prose programs are probabilistic. A rule that says *"always add `tools:` to a subagent"* is a
*request* — it works until the model forgets. The most important thing this plugin does is notice
when a request keeps being violated and **replace it with a deterministic guard**.

That is the recurrence → enforcement-creation flow:

1. The evaluator tags every finding with a stable signature (`subagent:missing-tools`,
   `skill:side-effecting-no-dmi`, …).
2. The planner detects **recurrence** — the same signature firing ≥3× in a run or ≥2× across runs.
3. Instead of emitting N one-off `kind: edit` fixes, it emits a `kind: create` row that scaffolds an
   *enforcing artifact*. The archetypes live in [`rules/dispatch.md`](rules/dispatch.md) →
   "Create-row dispatch": a recurring `subagent:missing-tools` becomes a `PreToolUse` hook that fails
   any `Edit(.claude/agents/*.md)` lacking `tools:`; a recurring `claude-md:vague-rules` becomes a
   path-scoped rule pinning the canonical wording.

A hook is Software 1.0 — explicit, deterministic, no model in the loop. So the pipeline runs
**3.0 → 1.0**: a probabilistic prose standard is compiled down into a guard that holds every time.
This repo dogfoods the pattern: [`hooks/calibrator-write-guard.sh`](hooks/calibrator-write-guard.sh)
is exactly such a guard — a deterministic 1.0 backstop enforcing a 3.0 contract (the calibrator's
allow-list) at the tool-call layer, so a prose instruction can never silently drift into an
out-of-bounds write.

> The plugin doesn't only clean up a setup — it **hardens** it, by turning the rules you keep
> breaking into rules you can't.

## The thesis applied to itself

The same discipline that the plugin recommends, it obeys:

- **Every shipped skill is `disable-model-invocation: true`** — descriptions leave context, Claude
  can't auto-fire them, idle cost is ~zero.
- **`rules/` is path-scoped** — `signatures.md` and `dispatch.md` load only when calibration files
  are open.
- **`hooks/` is zero-cost-unless-fires** — the write-guards exit early and silently when the active
  subagent isn't the calibrator.

A 3.0 program is only as good as the context budget it leaves for everything else. Costing nothing
when idle is not an optimisation here — it is the thesis, applied to the program that argues for it.

## See also

- [`README.md`](README.md) — the architecture and the calibration loop.
- [`rules/dispatch.md`](rules/dispatch.md) — the recurrence → enforcement archetypes.
- [`docs/glossary.md`](docs/glossary.md) — the vocabulary (enforcement-creation, recurrence, signature).
