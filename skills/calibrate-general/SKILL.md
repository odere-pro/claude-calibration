---
name: calibrate-general
description: >-
  Cross-cutting calibration synthesizer. Not bound to a single Claude Code feature — instead
  rolls up findings that span more than one: estimated always-on context cost (CLAUDE.md +
  unconditional rules), nested-CLAUDE.md conflict risk, settings precedence surprises, missing
  `.gitignore` coverage for `CLAUDE.local.md` / `.claude/settings.local.json` /
  `.claude/calibration/`, and "must"/"always"/"never" rules with no enforcement hook. Always
  emits the `general:diagnostics-ask` INFO so the evaluator reminds the user to paste `/doctor`,
  `/context all`, `/skills` (press `t`), `/mcp` for exact numbers. The lint script is also the
  back-end for `/calibrate cost` — its TSV output is read directly by the orchestrator's
  cost-mode formatter. Invoked by the calibration orchestrator (`/calibrate`) and standalone via
  `/claude-calibration:calibrate-general`.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# calibrate-general — per-feature bundle (cross-cutting synthesizer)

You synthesise cross-feature findings. Unlike other bundles whose lint takes individual files,
this bundle's `lint.sh` takes a **project directory** and walks it itself — the signatures it
emits are rollups of state across many files.

You receive one of two kinds of work:

- **Direct invocation** (`/claude-calibration:calibrate-general`) — run the synthesizer, report
  findings, propose fixes inline. The user drives the conversation.
- **Dispatch from the calibrator** — one approved plan row at a time, applied surgically.

The cost-mode entry point (`/calibrate cost`) reads this bundle's `lint.sh` output **directly**
and formats it for the user. Keep the TSV detail format stable — see "Detail format contract"
below.

## 1. Enumerate

```bash
bash <BUNDLE>/scripts/enumerate.sh "$PROJECT_DIR"
```

Yields a single row: `general\t<PROJECT_DIR>`. The bundle synthesises over the project itself.

## 2. Lint

```bash
bash <BUNDLE>/scripts/lint.sh "$PROJECT_DIR"
```

Yields TSV `path\tsignature\tseverity\tdetail`. The signatures this bundle owns
(see `reference.md`):

- `general:diagnostics-ask` (INFO) — **always emitted**
- `general:context-budget-overflow` (MEDIUM)
- `general:nested-claude-md-conflict` (LOW)
- `general:settings-precedence-surprise` (LOW)
- `general:no-gitignore-for-claude-local` (LOW)
- `general:must-rule-with-no-hook` (MEDIUM)

The script always exits 0, even when findings fire. Lint output is informational, not gated.

## Detail format contract

The orchestrator's cost-mode (`/calibrate cost`) parses the detail field of certain signatures:

- `general:context-budget-overflow` — detail must contain the substring `~Ntokens` (e.g.
  `"CLAUDE.md + unconditional rules ≈ ~6200tokens"`).
- `general:nested-claude-md-conflict` — detail must lead with an integer (e.g.
  `"5 nested CLAUDE.md files under project root"`).
- `general:must-rule-with-no-hook` — detail must lead with an integer (e.g.
  `"7 always/never/must lines across CLAUDE.md and 2 rules"`).
- `general:diagnostics-ask` — fixed reminder text (see template).

If you change the wording, preserve those parse anchors.

## 3. Fix — `kind: edit` rows

- `general:context-budget-overflow` → see `examples/context-budget-overflow/{before,after}.md`.
  Trim CLAUDE.md aggressively, add `paths:` frontmatter to language- or area-specific rules so
  they load on demand.
- `general:nested-claude-md-conflict` → consolidate nested CLAUDE.md files into one root file
  plus path-scoped rules; or accept the structure if the nesting is genuinely scoped.
- `general:no-gitignore-for-claude-local` → add the three patterns to `.gitignore`.
- `general:must-rule-with-no-hook` → either soften the rule wording (it's a Should, not a Must)
  or add a `PreToolUse` hook that enforces it (dispatch to `calibrate-hooks`).
- `general:settings-precedence-surprise` → reconcile with the managed policy owner; this is a
  governance finding, not a config bug per se.
- `general:diagnostics-ask` → informational — surface the four-diagnostics ask block in the
  final report.

## 4. Create — `kind: create` rows

Recurrences this bundle dispatches to its companions (per `rules/dispatch.md`):

- `general:must-rule-with-no-hook` ×N → calibrate-hooks scaffolds the matching enforcement hook.

## 5. Verify

After every edit, re-run `bash <BUNDLE>/scripts/lint.sh "$PROJECT_DIR"` and record `verify: ✓`
if the signature no longer fires.

## Hard rules

- The lint script MUST always exit 0.
- The lint script MUST always emit `general:diagnostics-ask` at least once.
- Detail-field parse anchors (`~Ntokens`, leading integer) MUST be preserved across edits — the
  cost-mode formatter keys on them.
