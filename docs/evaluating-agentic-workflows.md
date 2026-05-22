[← README](README.md) · [Usage](usage.md) · [Self-calibration](self-calibration.md) · [Evaluators](claude-evaluators.md)

# Evaluating agentic workflows

The calibration plugin grades **static config** — the files in `.claude/`. This page is about the
other half: grading the **behaviour** of a workflow that chains several agents and skills together,
where the real question is _"does this chain actually deliver the intent, and is every handoff
sound?"_ A PR code-review pipeline is the running example here, but the method is the workflow that
matters — it applies to any multi-step agentic flow (feature-dev, research, incident triage).

The discipline is the same one the plugin already uses on config (see
[`self-calibration.md`](self-calibration.md)): fan out small evaluators, score findings by severity,
score delivery against intent, watch for recurrence, then promote a durable fix. The only thing that
changes is _what_ you point it at.

## The three levels

A workflow fails in three different places, so you evaluate it at three levels. They map one-to-one
onto the three reports the plugin's own evaluator already produces
([`../agents/calibration-evaluator.md`](../agents/calibration-evaluator.md)):

| Level    | The question                                            | Plugin's analogue            | What you inspect                                                       |
| -------- | ------------------------------------------------------- | ---------------------------- | --------------------------------------------------------------------- |
| **Node** | Does each agent/skill do its one job well?              | `eval-features-*.md`         | the component on inputs it _should_ handle — precision, recall, scope |
| **Edge** | Are the agent→agent and agent→skill **handoffs** sound? | `eval-interactions-*.md`     | the contract across each seam — what's passed, what's lost            |
| **Flow** | Did the whole chain serve the **intent** end-to-end?    | `eval-intent-flow-*.md`      | acceptance criteria vs. what the workflow actually delivered          |

### Node level — each component in isolation

Treat every agent and skill as a unit under test. A reviewer agent that flags real bugs but also
30% false positives is a node-level defect; so is one whose scope silently overlaps another's. Ask:
does it catch what it's responsible for (recall), without crying wolf (precision), and only within
its remit (scope)?

### Edge level — the handoffs

This is the part single-component testing misses, and where chained workflows actually break. Each
agent→agent or agent→skill handoff is a **contract**: the producer emits an artifact, the consumer
expects a shape. The recurring failure modes:

- **Dropped context** — the downstream agent doesn't receive the diff slice / AC / prior findings it
  needs, and silently does a weaker job.
- **Lost findings** — a sub-reviewer reports an issue that the orchestrator's synthesis step never
  surfaces.
- **Duplicated work** — two nodes audit the same thing and you pay twice (and get conflicting
  severities).
- **Contract mismatch** — the consumer expects structured findings, the producer emits prose; the
  seam degrades to guesswork.
- **Severity drift** — each node scores on its own scale, so the final verdict can't be ranked.

### Flow level — end-to-end delivery

The pipeline can have great nodes and clean seams and _still_ not deliver — because nobody checked
the change against the **intent**. This is the "did the acceptance criteria get met?" question, and
it's exactly what the plugin's intent-flow report scores (next section).

## Scoring vocabulary (reuse, don't invent)

Borrow the plugin's two scales so workflow evaluations read the same as config evaluations:

- **Findings** — one severity scale, from [`../rules/signatures.md`](../rules/signatures.md):
  `CRITICAL > HIGH > MEDIUM > LOW > INFO`. A security hole the pipeline missed is CRITICAL; a
  reviewer's stylistic nit is LOW.
- **Delivery** — map each acceptance criterion to `met | partial | blocked | unknown`, then give the
  whole run an `Intent service score: <low|mid|high> — <one-line rationale>`. That is verbatim the
  format the evaluator uses for `eval-intent-flow-*.md` (its step 7). Acceptance criteria _are_ the
  success criteria; "did AC match the intent" is the intent-flow table.
- **Stable signatures** — name each recurring finding `<area>:<short-name>` (e.g.
  `review:security-missed`, `handoff:ac-not-passed`) so you can count recurrences across runs. The
  plugin's whole recurrence→enforcement engine depends on names being stable — its catalogue
  ([`../rules/signatures.md`](../rules/signatures.md)) treats every signature name as a contract.

## You can't grade behaviour statically — use cases

Config can be linted by reading it. Behaviour can't: you only learn whether the code-review flow
catches a SQL-injection if you _run it on a PR that has one_. So the unit of a workflow evaluation is
a **case set** — the behavioural analogue of the static lint:

- **Known-good input** → the flow should pass it clean (no false alarms).
- **Known-defect input** → each planted defect must be caught **by the right node** at the right
  severity. (Catching a security bug in the style reviewer is still a node/edge defect.)
- **Adversarial input** → oversized diff, mixed concerns, misleading PR description.
- **AC-mismatch input** → code that works but doesn't do what the ticket asked — the flow level must
  flag it `blocked`/`partial`, not wave it through.

Run the workflow over the set, then diff **actual findings vs. expected**. The gaps are your
node/edge/flow findings.

## Worked example — a PR code-review pipeline

Decompose the workflow into nodes by **concern**, using evaluators already catalogued in
[`claude-evaluators.md` → Beyond config](claude-evaluators.md#beyond-config):

| Concern               | Node(s)                                                       | Level it lives at      |
| --------------------- | ------------------------------------------------------------ | ---------------------- |
| Code quality          | `code-reviewer` + `<lang>-reviewer`, `code-simplifier`       | node                   |
| Acceptance ↔ intent   | an intent-checker comparing the diff to the PR body / ticket | flow                   |
| Security & risk       | `security-reviewer`, `silent-failure-hunter`                 | node (+ flow coverage) |
| Test adequacy         | `pr-test-analyzer`                                            | node                   |
| Types / contracts     | `type-design-analyzer`                                       | node                   |
| Full PR review        | a `review-pr` / `code-review` skill that orchestrates + synthesises | edge + flow     |

Then evaluate the pipeline, not just the pieces:

- **Node check (one example):** feed `security-reviewer` ten PRs with one planted vuln each. Recall =
  caught / 10; precision = real / flagged. Below your bar → `review:security-missed` HIGH.
- **Edge check (one example):** does the orchestrator hand each reviewer the **same diff revision**,
  de-duplicate overlapping findings, and **normalise severities** onto one scale before it
  synthesises? A finding raised by `silent-failure-hunter` that never reaches the final summary is
  `handoff:finding-dropped` HIGH.
- **Flow check (one example):** the intent-flow table for one run —

  | Acceptance criterion                     | Status  | Top blocker                                  |
  | ---------------------------------------- | ------- | -------------------------------------------- |
  | Rate-limit the login endpoint            | met     | —                                            |
  | Log failed attempts for audit            | partial | logged, but no test covers the path          |
  | No new secrets committed                 | met     | —                                            |
  | Backwards-compatible with v1 clients     | blocked | no node evaluates API compatibility at all   |

  `Intent service score: mid — security/quality covered, but AC "v1 compatibility" has no owner in
  the pipeline.` That last row is a **coverage gap**: a concern the intent needs and no node owns.

## The same lens on other workflows

The node/edge/flow decomposition is workflow-agnostic:

| Workflow            | Node                                  | Edge                                          | Flow                                       |
| ------------------- | ------------------------------------- | --------------------------------------------- | ------------------------------------------ |
| Feature development | planner / coder / test-writer quality | does the plan's task list reach the coder?    | did the shipped feature meet the spec?     |
| Research / RAG      | retriever, summariser, verifier       | are retrieved passages passed with citations? | did the answer actually address the query? |
| Incident triage     | classifier, root-cause, responder     | does severity survive the handoff to paging?  | was the right incident resolved, in time?  |

## Closing the loop — recurrence → enforcement

A one-off miss is a bug; the **same** miss across runs is a workflow defect that wants a durable fix.
This mirrors the plugin's `kind: edit` vs `kind: create` split
([`usage.md`](usage.md#the-recurrence--enforcement-creation-flow)):

- **Recurring node miss** → tighten that node — sharpen its prompt, add a tool, narrow its scope.
- **Recurring seam drop** → add a **handoff contract check** (assert the artifact shape at the seam).
- **Recurring class of escape** → add a **deterministic gate** outside the agents entirely — a CI
  check, a lint rule, a `PreToolUse`/`Stop` hook — so the workflow _cannot_ regress on it. Agents are
  probabilistic; the things you can make deterministic, you should.

## How this could grow into the plugin

Today this is methodology, not a feature — the calibration plugin is static-config only and does
**not** run workflow evaluations. A future capability would need three things the static engine
doesn't have: a **flow-evaluator** agent that drives a workflow over a case set, an `eval-flow-*.md`
report type, and a **fixtures / golden-case harness** to hold the known-good / known-defect inputs.
The runtime building blocks already exist elsewhere and are catalogued under
[`claude-evaluators.md` → Beyond config](claude-evaluators.md#beyond-config): `gan-evaluator`
(drives a live app, scores against a rubric, feeds back), `eval-harness` and `verification-loop`
(structured eval / verify-retry loops), and `e2e-runner` (end-to-end flows). `harness-optimizer`
already reasons about agent definitions and model routing across a setup.

## Concrete interfaces (proposed — not yet shipped)

The config-side iteration track now ships (`/calibration-track`, see
[usage.md](usage.md#tracking-improvement-across-iterations)): it snapshots config quality
deterministically and reports improvement vs a baseline and vs the previous iteration. The
behavioural harness is the **next phase** — these are the three interfaces it needs, specified here
so a later PR can build them. None of these components ship yet; the plugin is still static-config
only.

1. **`calibration-flow-evaluator` (a worker subagent).** Input: a workflow id (the orchestrating
   skill/agent under test), a **case set** path, and the run folder. It drives the workflow over each
   case, diffs actual findings against expected, and writes the report below. Mirrors the contract of
   the existing `calibration-evaluator` ([`../agents/calibration-evaluator.md`](../agents/calibration-evaluator.md))
   but points at behaviour, not files.

2. **`eval-flow-<ts>.md` (a report type).** One section per level, reusing the shared scales:
   - **Node** — per component: `recall`, `precision`, `scope`; findings tagged `<area>:<short-name>`
     at `CRITICAL > HIGH > MEDIUM > LOW > INFO`.
   - **Edge** — per handoff: contract check (artifact shape passed vs expected), with
     `handoff:*` signatures (`handoff:ac-not-passed`, `handoff:finding-dropped`, …).
   - **Flow** — the intent-flow table (`met | partial | blocked | unknown` per acceptance criterion)
     plus `Intent service score: <low|mid|high>` — verbatim the evaluator's `eval-intent-flow-*.md`
     format, so behavioural and config runs read the same.

3. **`fixtures/` (a golden-case harness).** A directory of cases, each
   `fixtures/<case>/{input, expected.md}`, covering the four input classes from
   [You can't grade behaviour statically](#you-cant-grade-behaviour-statically--use-cases):
   known-good, known-defect, adversarial, AC-mismatch. `expected.md` lists which node should catch
   each planted defect, at what severity — the oracle the evaluator diffs against.

With those three, the same recurrence → enforcement loop applies: a recurring `handoff:*` or
`<area>:*` signature promotes to a durable fix (a handoff contract check, a deterministic gate),
exactly as config recurrences promote today.

## Scope & limits

This is **behavioural** evaluation and sits outside what `/calibrate` does — see
[`usage.md` → Limits](usage.md#limits) ("this skill never actually fires … need a transcript scan or
a live measurement"). The vocabulary here (severity, intent-flow scoring, signatures, recurrence) is
shared with the config side so the two stay consistent; the _mechanism_ (running a workflow over
cases) is yours to build with the tools above.

## Sources

- The three-report model and the intent-flow scoring format —
  [`../agents/calibration-evaluator.md`](../agents/calibration-evaluator.md).
- The severity scale and signature contract — [`../rules/signatures.md`](../rules/signatures.md),
  [`../rules/dispatch.md`](../rules/dispatch.md).
- The config-side loop this generalises from — [`self-calibration.md`](self-calibration.md),
  [`usage.md`](usage.md).
- The concrete review / runtime evaluators used as examples —
  [`claude-evaluators.md`](claude-evaluators.md) (the "Beyond config" section).
- What agents and skills are, as units — [`features/subagents.md`](features/subagents.md),
  [`features/skills.md`](features/skills.md).
