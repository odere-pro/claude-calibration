[← README](README.md) · [Install](install.md) · [Glossary](glossary.md) · [Setup structure](claude-structure.md)

# Usage — `claude-calibration`

A walkthrough of how to drive the plugin, from your first run to the per-feature shortcuts and the
recurrence → enforcement-creation flow that's its highest-leverage feature.

**On this page:** [First run](#your-first-run) · [Setting an intent](#setting-an-intent) ·
[Resume / restart / status](#resuming-restarting-status) · [Per-feature usage](#per-feature-usage) ·
[Recurrence → enforcement](#the-recurrence--enforcement-creation-flow) ·
[3-vs-4-layer call](#the-3-vs-4-layer-call) · [Convenience flows](#convenience-flows) ·
[Run-folder files](#reading-the-run-folder-files) · [Reverting](#reverting) ·
[Auditing this plugin](#auditing-this-plugin-itself) · [Limits](#limits)

## Your first run

```text
/calibrate
```

That's it. With no argument the orchestrator either **resumes** the last in-progress run, or starts
a new one with a **guessed intent**. The guessed default is sensible — _"reduce always-on context
cost without losing capability, and close obvious reliability/safety gaps"_. The orchestrator says
the guess in one line so you can re-run with a different intent if it's wrong:

```text
No intent given — calibrating toward: «reduce always-on context cost without losing capability…».
Re-run /calibrate "<your goal>" to change it.
```

After that you'll see:

1. **Phase 1 — Plan initialised.** A run folder is created at
   `.claude/calibration/<timestamp>/`; `plan.md` is written; `.claude/calibration/current`
   remembers the run.
2. **Phase 2 — Baseline evaluation.** The evaluator **fans out** to 9 parallel
   `calibration-feature-evaluator` workers (one per feature, haiku-class), each running its
   bundle's `enumerate.sh` + `lint.sh` and writing a per-feature draft. The evaluator merges
   the drafts and adds the two cross-feature reports
   (`eval-interactions-*.md`, `eval-intent-flow-*.md`). Net effect: one wall-clock pass over
   all 9 features instead of nine sequential passes. Token cost scales with feature count;
   compute cost is roughly 9× a single-feature audit.
3. **Phase 3 — Improvement plan.** The planner reads the eval reports, groups findings by pattern
   signature, and rewrites `plan.md` with a prioritised plan. Recurring patterns produce **`kind:
   create`** rows (enforcement); one-off findings produce **`kind: edit`** rows.
4. **The approval gate.** The orchestrator shows you a compact table — `id · sev · scope · risk ·
   one-line change` — and asks: _"Reply: `all` / `safe-only` / `project-only` / `<comma-separated
   ids>` / `skip`"_.
5. **Phase 5 — Calibrate.** The calibrator dispatches each approved row through its bundle's
   templates / examples, applies project-scope changes, writes user-scope changes up as
   recommendations, and re-runs each bundle's `lint.sh` to verify.
6. **Phase 6 — Delta evaluation.** The evaluator re-audits; `plan.md` records `last_evaluation`.
7. **Phase 7 — Final report.** The orchestrator composes the report from the run-folder files,
   prints it to stdout, and saves a copy at `<run>/final-report-*.md`.

The orchestrator's messages between phases are intentionally **terse** (3–5 lines). All detail lives
in the run-folder files. Read `plan.md` if you want the state, or the eval reports if you want
specifics.

## Setting an intent

```text
/calibrate "<your goal>"
```

The intent steers the entire run — the evaluator weights findings by intent flow, the planner orders
the plan by intent alignment, and the planner's **auto-promote** rule for enforcement-creation rows
keys on intent text.

Common intents and what they do:

| Intent | Effect |
|---|---|
| `"reduce always-on context cost"` | Findings that bloat the standing context (oversized CLAUDE.md, broad rule files with no `paths:`, side-effecting skills missing `disable-model-invocation`) are prioritised. |
| `"tighten standards"` | Recurring fixes are **auto-promoted** to `create` rows — the planner scaffolds enforcement (hooks, rules, wrapper skills) rather than just one-off edits. |
| `"prevent recurrence of <X>"` | Same — auto-promote keyword. |
| `"standardize <something>"` / `"harden <something>"` | Same — auto-promote keywords. |
| `"make the TDD loop reliable"` | Findings related to test/verify hooks, `Stop`-hook coverage, and CLAUDE.md "must test" rules with no enforcement are weighted up. |
| `"fix obvious safety gaps"` | CRITICAL findings (committed secrets, `--dangerously-skip-permissions`, blanket-destructive `permissions.allow`) are prioritised and risky rows are flagged. |
| `"prepare for a team audit"` | All scopes weighted equally; user-scope changes show up as recommendations with concrete edit-by-hand instructions. |

The auto-promote rule (planner step 5) matches the intent text against
`enforce | tighten | prevent recurrence | standardi[sz]e | harden` (case-insensitive). When it
matches, recurring patterns become `create` rows **in the main table**; otherwise they're listed
under `### Enforcement opportunities` for you to opt into by id during the approval gate.

## Resuming, restarting, status

`/calibrate` resumes by default — it reads `.claude/calibration/current`, opens that run's
`plan.md`, finds `last_phase_completed`, and picks up at the next phase.

| Command | What it does |
|---|---|
| `/calibrate` | Resume the current run, or start a new one if there isn't one. |
| `/calibrate "<new goal>"` | Start a new run with this intent (the previous run is left as history). |
| `/calibrate restart` | Same — explicit fresh start. |
| `/calibrate status` | Print the current run's state: intent + source, log folder, `last_phase_completed`, the phase checklist with ✓/▢, severity counts, the `→ Next:` step. No phase actually runs. |
| `/calibrate --yes` | Skip the approval gate (apply all planned changes). Use cautiously — see _Limits_ below. |

The state is **durable across `/clear`** — `plan.md`'s frontmatter (`last_evaluation`,
`touched_files`, etc.) is the source of truth. If you `/clear` mid-run, just run `/calibrate` again.

There is a **drift check** on resume: if `GIT_HEAD` has changed substantially since the run started,
or if there are many dirty files beyond what `touched_files` accounts for, the orchestrator warns
and asks whether to `continue` or `/calibrate restart`.

## Per-feature usage

When you don't need the full orchestration — just a focused pass over one feature — invoke a bundle
directly:

```text
/claude-calibration:calibrate-skills        # every SKILL.md
/claude-calibration:calibrate-subagents     # every agent .md
/claude-calibration:calibrate-claude-md     # CLAUDE.md / CLAUDE.local.md
/claude-calibration:calibrate-rules         # .claude/rules/**
/claude-calibration:calibrate-settings      # every settings.json layer
/claude-calibration:calibrate-hooks         # every hooks block
/claude-calibration:calibrate-mcp           # .mcp.json + subagent mcpServers frontmatter
/claude-calibration:calibrate-plugins       # enabled plugins + this plugin's own manifest
/claude-calibration:calibrate-general       # cross-cutting (context budget, layering hazards, …)
```

Each bundle runs its `enumerate.sh` → `measure.sh` → `lint.sh` workflow, prints a findings table,
and asks before editing anything. They're `disable-model-invocation: true`, so Claude can never
auto-fire one — you always type the slash command yourself.

**One worked example** — say `/skills` shows your skill listing is overflowing. Run:

```text
/claude-calibration:calibrate-skills
```

The bundle enumerates every SKILL.md (user + project + enabled plugins), measures
description/body/`disable-model-invocation` per skill, and lints them. You'll get a table like:

```
~/.claude/skills/deploy-prod/SKILL.md       skill:side-effecting-no-dmi   HIGH
~/.claude/skills/release/SKILL.md           skill:side-effecting-no-dmi   HIGH
.claude/skills/kubectl-recipes/SKILL.md     skill:cli-not-wrapped         LOW
.claude/skills/aws-recipes/SKILL.md         skill:cli-not-wrapped         LOW
```

It then asks which findings to apply. The `side-effecting-no-dmi` rows are one-liner edits (add
`disable-model-invocation: true`). The two `cli-not-wrapped` rows on different CLIs stay as edits;
but if they were on the same CLI (e.g. both shelling `kubectl`), the planner in the full
`/calibrate` flow would have detected recurrence and offered to create a wrapper skill from
`templates/cli-wrapper.tmpl` — see the next section.

## The recurrence → enforcement-creation flow

This is the plugin's central insight: **the same finding repeating across rows is itself a signal**.
Three subagents missing `tools:`, four skills lacking `disable-model-invocation`, two skills both
shelling out to `kubectl`. The planner detects these patterns and offers to **scaffold a new feature
into your setup** that prevents the same issue recurring — rather than just fixing each instance by
hand.

How it works:

1. The evaluator emits a **pattern signature** with every finding (e.g. `subagent:missing-tools`,
   `skill:cli-not-wrapped`, `claude-md:vague-rules`). The signatures are catalogued in
   [`rules/signatures.md`](../rules/signatures.md) and in each bundle's `reference.md`.
2. The planner groups findings by signature. A signature with **≥ 3 occurrences in this plan** or
   **≥ 2 occurrences across older runs** is a recurrence.
3. Each recurrence emits a `kind: create` row in addition to the per-instance `kind: edit` rows.
   Common archetypes:

   | Recurring signature | The `create` row it offers |
   |---|---|
   | `subagent:missing-tools` (×N) | A `PreToolUse` hook scoped to `Edit(.claude/agents/*.md)` that exits 2 if `tools:` is absent — routed through `calibrate-hooks`. |
   | `skill:side-effecting-no-dmi` (×N) | A similar hook on `Edit(.claude/skills/*/SKILL.md)` — `calibrate-hooks`. |
   | `claude-md:vague-rules` (×N) | A path-scoped rule in `.claude/rules/conventions.md` listing the canonical wordings — `calibrate-rules`. |
   | `skill:cli-not-wrapped` (×N for the same CLI) | **3→4-layer promotion** — a wrapper skill from `calibrate-skills/templates/cli-wrapper.tmpl`. |
   | `mcp:no-skill-pair` (×N for the same server) | Wrapper from `calibrate-skills/templates/mcp-wrapper.tmpl`. |
   | `hook:exit-1-non-blocking` (×N) | A doc-rule + a CI lint + a `Stop` hook — `calibrate-rules` + `calibrate-hooks`. |

4. **Auto-promote.** If the intent matches `enforce | tighten | prevent recurrence | standardi[sz]e
   | harden`, the `create` rows go straight into the main plan table. Otherwise they appear under
   `### Enforcement opportunities` at the bottom of `plan.md` for you to opt in by id at the
   approval gate.
5. Either way, the calibrator dispatches the `create` row through its bundle — the template fills
   from the row's `change` spec, the artifact is scaffolded at the row's `file` path, and
   `lint.sh` verifies the result.

The plugin doesn't only clean a setup up. It **hardens** it — each run can leave behind a hook, a
rule, or a wrapper skill that prevents the same finding from coming back.

## The 3-vs-4-layer call

Claude Code capabilities have two valid shapes:

- **3-layer (in-repo only):** Claude does the work directly with `Read` / `Edit` / `Write` /
  `Glob` / `Grep` ± in-repo `scripts/`. Right for refactor patterns, code-style fixes, doc
  generation, config audits, in-repo workflow.
- **4-layer (CLI- or MCP-integrated):** A skill wraps an **external** CLI or MCP server, making it
  discoverable and useful to Claude (recipe library, schema docs, common-query patterns). Right
  when the same external tool is touched repeatedly.

The evaluator scores each capability against the right rubric (see the [`layer`](glossary.md)
glossary entry for the call). The two flagging signatures:

- **`skill:cli-not-wrapped`** — a skill body shells out to `gh` / `kubectl` / `aws` / `pnpm` /
  `gcloud` / `docker` / `terraform` / `helm` repeatedly without a scoped `Bash(<tool> *)`
  `allowed-tools` entry. Promote to 4-layer via `templates/cli-wrapper.tmpl`.
- **`mcp:no-skill-pair`** — an MCP server in `.mcp.json` with no paired wrapper skill. Promote via
  `templates/mcp-wrapper.tmpl`.

And one **anti**-signature that prevents a wrong-direction promotion:

- **`skill:in-repo-only-ok`** — the skill only does in-repo file ops with no external touch. Don't
  push it to 4-layer; a wrapper would be ceremony.

## Convenience flows

For common workflows there are pre-set entries:

Three of these are **modes built into `/calibrate`** (no separate skill — `/calibrate` recognises
the token and dispatches the right pipeline). The other two are **separate skills** because they
spawn their own subagent chain and need their own preprocessing block:

| Command | What it does | Use when |
|---|---|---|
| `/claude-calibration:calibration` | Top-level dispatcher: with no args prints a menu of the flows; with a flow name delegates (to `/calibrate <mode>` or to the right skill); otherwise treats the input as the intent and forwards to `/calibrate`. | You've forgotten which command runs what. |
| `/calibrate tighten` | Rewrites to intent `"tighten standards"` — pre-fills the auto-promote keyword. | One-token harden flow. |
| `/calibrate harden` | Rewrites to `"tighten standards" --yes` — auto-promote + skip approval. **Risky** — guarded by the calibrator-write-guard hook. | Trusted, well-understood plans (or CI runs that explicitly opted in). |
| `/calibrate cost` | Runs `calibrate-general/scripts/lint.sh` + the diagnostics ask. No run, no subagents, no edits. | The single-number standing-context-cost check. |
| `/claude-calibration:calibration-audit` | Runs `/calibrate` through Phase 2 only — baseline evaluation, no improvement plan, no edits. Pure read-only audit. Enforced read-only by the audit-write-guard hook. | Periodic health check; CI gate; "just tell me what's wrong". |
| `/claude-calibration:calibration-diff` | Evaluator pass-2 against the previous run's baseline; no planner / calibrator. | "What's changed since last calibration?" — useful between runs or after manual edits. |
| `/claude-calibration:calibration-doctor` | Fast structural health check (~5s). Runs `scripts/doctor.sh`: JSON parses, hook scripts exist + executable, frontmatter is valid, MCP commands resolve, `.gitignore` covers `.claude/calibration/`. Triage list (broken/warn/ok). No rubric grading. | Pre-commit / pre-push smoke check; after a hand-edit; CI smoke gate. |
| `/claude-calibration:calibration-onboarding` | First-time setup guide. Detects existing config + stack signals (TS/Python/Go/Rust/etc.) and names a single minimal next step. Pure guidance — never writes a config file. | Picking up a project with no Claude Code setup; orienting a teammate before they run `/calibrate`. |

All convenience flows are thin wrappers — they exist for discoverability and to pre-set common
argument combinations. You can always invoke `/calibrate` directly with the equivalent args.

## Reading the run-folder files

`<project>/.claude/calibration/<timestamp>/` is laid out like this:

```
<run>/
├── plan.md                       # the source of truth: frontmatter (state) + Phases + Intent + Improvement plan
├── eval-features-<ts>.md         # per-feature findings (one section per bundle)
├── eval-interactions-<ts>.md     # cross-cutting findings (context budget, layering hazards, …)
├── eval-intent-flow-<ts>.md      # what advances the intent / what obstructs / gaps
├── calibration-report-<ts>.md    # what was applied, recommended, skipped (after Phase 5)
├── eval-delta-<ts>.md            # before → after on every baseline finding (after Phase 6)
└── final-report-<ts>.md          # the printed final report (after Phase 7)
```

What to look at when:

- **Mid-run, want to know where you are:** `/calibrate status` (it reads `plan.md`'s frontmatter).
- **Want the full plan before approving:** `<run>/plan.md` — the table under `## Improvement plan`
  plus `### Enforcement opportunities` if any rows weren't auto-promoted.
- **Want the per-feature reasoning:** `<run>/eval-features-*.md` — one `## <Feature>` section per
  bundle, with a findings table (`severity · scope · rule/limit · actual · expected · note`).
- **Want to share what changed with a teammate:** `<run>/final-report-*.md` is the canonical
  artifact — the orchestrator also prints it to stdout, but the file is the durable copy.
- **Want to see what was actually touched:** `plan.md`'s `touched_files` frontmatter (path + sha256
  per file the calibrator wrote).

`plan.md`'s `last_evaluation` field is the **durable record** across `/clear` — read it for the
before→after counts without needing the full delta file.

## Reverting

Project-scope changes (under `<project>/CLAUDE.md`, `.claude/**`, `.mcp.json`, the project's
`AGENTS.md`, `.gitignore`):

```bash
git diff                         # see exactly what changed
git status                       # confirm the calibrator only touched expected paths
git revert <commit>              # revert a calibration commit cleanly
# or
git checkout HEAD -- <path>      # revert a single file
```

The calibrator records `touched_files` in `plan.md` frontmatter — cross-check it against `git
status` to be sure nothing escaped the allow-list.

**User-scope changes** (anything under `~/.claude/**` or `~/.claude.json`): the calibrator does
**not** apply these. They appear in `<run>/calibration-report-*.md` under "Recommended (not applied)"
with the exact edit / command you'd run. Apply them by hand, and they're your responsibility to
revert.

## Auditing this plugin itself

> For the full loop internals — the six phases, the worker agents and their models, and the
> write-guards — see [`self-calibration.md`](self-calibration.md). This section covers the
> plugin-self specifics.

The plugin can audit its own setup — the eat-our-own-dogfood loop. When the project you're running
`/calibrate` from is itself a plugin (a `.claude-plugin/plugin.json` exists at the root), three
bundles automatically extend their scope to include plugin-root files:

- **`calibrate-rules`** enumerates `<plugin-root>/rules/**/*.md` in addition to the standard
  `.claude/rules/` and `~/.claude/rules/`.
- **`calibrate-hooks`** enumerates `<plugin-root>/hooks/*` in addition to the standard locations.
- **`calibrate-plugins`** already self-detected `skills/`, `agents/`, etc. — it now also recognises
  `rules/` as a valid plugin-root component (and flags it as misplaced if found inside
  `.claude-plugin/` instead).

And the **calibrator-write-guard hook** extends its allow-list when `<project>/.claude-plugin/plugin.json`
exists, so the calibrator subagent can actually apply fixes to `rules/`, `hooks/`, `skills/`,
`agents/`, `bin/`, `monitors/`, `.mcp.json`, `.lsp.json`, and the manifest itself. Non-plugin
projects don't see this extension — their allow-list is still `<project>/.claude/**` only.

### Worked example

```bash
cd /path/to/claude-calibration                          # this repo (or any other plugin repo)
claude --plugin-dir .                                    # load the plugin in dev mode
```

In the session:

```text
/calibrate "audit this plugin's setup"
```

What to expect:

- **Phase 2 (baseline-eval)** — the per-feature reports now include sections for plugin-root files:
  `eval-features-*.md` has rows where `scope: plugin-self` and `path` is e.g.
  `rules/signatures.md` or `hooks/audit-write-guard.sh`.
- **A new signature you might see** — `rule:plugin-shipped-no-paths` HIGH on any rule under
  `<plugin>/rules/` that lacks `paths:` frontmatter. The plugin's own
  [`rules/signatures.md`](../rules/signatures.md) and [`rules/dispatch.md`](../rules/dispatch.md)
  carry `paths:` deliberately, so they pass — verify by reading their frontmatter.
- **Phase 3 (planner-improve)** — `plan.md`'s improvement table has rows where `file:` is at the
  plugin root (`rules/foo.md`, `hooks/bar.sh`).
- **Phase 5 (calibrate)** — the calibrator applies those rows without `[calibrator-write-guard]
  BLOCKED` errors, because the allow-list now covers plugin-root paths.
- **Phase 6 (delta-eval)** — the new signatures show as resolved.

### When to use this

- **After adding a new plugin component** — a fresh `rules/` file, a new hook script — and you want
  to confirm it meets the rubric (path-scoped, locally-sourced, uses `exit 2`, etc.).
- **Before bumping the manifest `version`** — run `/calibrate "audit this plugin's setup"` as a
  pre-release gate; fix any HIGH or CRITICAL findings before publishing.
- **As part of `/plugin-update`** — when the upstream docs change a limit (e.g. a new frontmatter
  key), `/plugin-update` realigns the bundles' `reference.md`/`templates/`/`lint.sh`, then a
  self-audit confirms the plugin's own files match the now-current rubric.

### What doesn't change

- **`~/.claude/`** is still audited the same way (user-scope is always in scope).
- **The other 5 per-feature bundles** (`calibrate-{claude-md, settings, skills, subagents, mcp}`)
  don't have a plugin-self mode because their target files don't have a plugin-payload analogue —
  a plugin doesn't ship a CLAUDE.md, settings.json, etc. as part of its payload.
- **Non-plugin projects** see no behaviour change. The plugin-self enumeration / write-guard
  extension is gated on `<project>/.claude-plugin/plugin.json` existing.

## Limits

The plugin is **structural** — it audits your config files and reasons over the rubric. It does not:

- **Replace the built-in diagnostics.** `/doctor`, `/context all`, `/skills` (with `t` to sort by
  token cost), and `/mcp` are CLI-handled and **can't be invoked by an agent**. The evaluator
  estimates the numbers from config; its first report section asks you to paste those four outputs
  for the exact figures. (This is the "four diagnostics ask".)
- **Auto-apply user-scope changes.** Anything under `~/.claude/**` is recommendation-only. Writes
  outside the repo always prompt anyway; the calibrator captures the recommendation rather than
  trying to write through the prompt.
- **Edit anything outside Claude Code config.** The calibrator's allow-list is `<project>/CLAUDE.md`,
  `.claude/**`, `.mcp.json`, `AGENTS.md`, and `.gitignore`. Source code, `package.json`, lockfiles,
  CI config, the `docs/` folder, the plugin's own files are all off-limits. The shipped
  `PreToolUse` write-guard hook enforces this at runtime.
- **Run forever.** The calibrator subagent caps at `maxTurns: 40`. A plan whose total complexity
  blows that cap finishes what it can and reports the rest as "Skipped: out of budget"; re-run
  `/calibrate` to pick up where it stopped.
- **Detect dynamic problems.** Things like "this hook is too slow", "this MCP server returns no
  data 30% of the time", or "this skill never actually fires" need a transcript scan or a live
  measurement — out of scope for a static audit. The `harness-optimizer` plugin agent does some of
  this; this plugin focuses on the config files themselves. For a methodology to evaluate the
  behaviour of multi-agent workflows themselves, see
  [`evaluating-agentic-workflows.md`](evaluating-agentic-workflows.md).

Once you have those four diagnostic outputs pasted in `<run>/eval-features-*.md`, the next run will
have exact numbers rather than estimates.

## Sources

- The orchestrator's behaviour — [`../skills/calibrate/SKILL.md`](../skills/calibrate/SKILL.md).
- The worker agents — [`../agents/calibration-planner.md`](../agents/calibration-planner.md),
  [`../agents/calibration-evaluator.md`](../agents/calibration-evaluator.md),
  [`../agents/calibration-calibrator.md`](../agents/calibration-calibrator.md),
  [`../agents/calibration-feature-evaluator.md`](../agents/calibration-feature-evaluator.md)
  (per-feature worker the evaluator fans out to in parallel).
- Per-feature rubrics — each bundle's `reference.md` under `../skills/calibrate-<feature>/`.
- Underlying Claude Code feature mechanics — `features/*.md` in this doc-set and their
  `code.claude.com/docs/*` sources.
