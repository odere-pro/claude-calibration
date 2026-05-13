---
name: calibrate-claude-md
description: >-
  Audits `CLAUDE.md`, `CLAUDE.local.md`, and every nested `**/CLAUDE.md` across user / project
  scopes. Flags committed secrets, files over 200 / 400 effective lines, aspirational ("must" /
  "always" / "never") wording that should be a hook, vague rules without specifics, `@`-import
  chains > 5 hops, contradictions between nested files, and `AGENTS.md` siblings that are present
  but un-imported. Also scaffolds trimmed CLAUDE.md replacements when a file is over budget — the
  removed content moves into `.claude/rules/<topic>.md` with `paths:` scoping (companion work in
  `calibrate-rules`). Invoked by the calibration orchestrator (`/calibrate`) and standalone via
  `/claude-calibration:calibrate-claude-md`.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(bash *), Edit(**/CLAUDE.md), Edit(**/CLAUDE.local.md), Write(**/CLAUDE.md), Write(**/CLAUDE.local.md)
---

# calibrate-claude-md — per-feature bundle

You audit and tune `CLAUDE.md` / `CLAUDE.local.md` / nested `**/CLAUDE.md`. You receive one of two
kinds of work:

- **Direct invocation** (`/claude-calibration:calibrate-claude-md`) — audit everything, report
  findings, propose fixes inline. The user drives the conversation.
- **Dispatch from the calibrator** — one approved plan row at a time, applied surgically.

In both cases the workflow is the same; only the framing differs.

## 1. Enumerate

```bash
bash <BUNDLE>/scripts/enumerate.sh "$PROJECT_DIR"
```

Yields TSV `scope\tpath`. Scope is `user` (`~/CLAUDE.md`, `~/.claude/CLAUDE.md`), `project`
(`<PROJECT_DIR>/CLAUDE.md`, `<PROJECT_DIR>/CLAUDE.local.md`), or `nested` (any other
`<PROJECT_DIR>/**/CLAUDE.md`).

## 2. Lint

```bash
bash <BUNDLE>/scripts/lint.sh <path …>
```

Yields TSV `path\tsignature\tseverity\tdetail`. The signatures this bundle owns
(see `reference.md`):

- `claude-md:secret-leak` (CRITICAL)
- `claude-md:over-200` (MEDIUM)
- `claude-md:over-400` (HIGH)
- `claude-md:vague-rules` (MEDIUM)
- `claude-md:no-agents-md-import` (LOW)
- `claude-md:imports-too-deep` (HIGH)
- `claude-md:contradicts-nested` (MEDIUM)
- `claude-md:must-rule-with-no-hook` (MEDIUM)
- `claude-md:restated-readme` (LOW)

## 3. Fix — `kind: edit` rows

For each finding, the remediation pattern is in `examples/<case>/`:

- `claude-md:over-200` / `claude-md:over-400` → `examples/over-200/{before,after}.md` (trim the
  CLAUDE.md; move topic blocks into `.claude/rules/<topic>.md` with `paths:` — companion work in
  `calibrate-rules`).
- `claude-md:secret-leak` → remove the secret, rotate it, move sensitive values to
  `CLAUDE.local.md` (git-ignored) or `.env`.
- `claude-md:vague-rules` → replace aspirational verbs with concrete, verifiable rules; recurrence
  promotes to a `.claude/rules/conventions.md` (companion work in `calibrate-rules`).
- `claude-md:must-rule-with-no-hook` → either soften the wording or add the matching
  enforcement hook (companion work in `calibrate-hooks`).
- `claude-md:no-agents-md-import` → add `@AGENTS.md` near the top of CLAUDE.md.
- `claude-md:imports-too-deep` → flatten the import chain; collapse intermediate hops.
- `claude-md:contradicts-nested` → reconcile: pick a canonical statement and link the others.
- `claude-md:restated-readme` → replace duplicated content with `@README.md` or a link.

## 4. Create — `kind: create` rows

When the planner detects a recurrence that this bundle scaffolds, the create row is usually
routed to a sibling bundle (per `rules/dispatch.md`):

- **`claude-md:over-200` ×N** → companion `calibrate-rules` `create` row scaffolds the new
  path-scoped rule file containing the moved-out block.
- **`claude-md:vague-rules` ×N** → `calibrate-rules` scaffolds `.claude/rules/conventions.md`.
- **`claude-md:must-rule-with-no-hook` ×N** → `calibrate-hooks` scaffolds the matching enforcement
  hook.

This bundle owns `templates/claude-md.tmpl` (used when a CLAUDE.md is being recreated from
scratch — a fresh project, or a full rewrite after a `secret-leak`).

## 5. Verify

After every edit or create, re-run `bash <BUNDLE>/scripts/lint.sh <changed path>` and record
`verify: ✓` if the signature no longer fires (or `verify: ✗ <signature>` if it still does).

## Hard rules

- Never trim load-bearing content silently — when removing a block, either move it to
  `.claude/rules/<topic>.md` with appropriate `paths:` scoping, or surface the removal in the plan.
- `CLAUDE.md` is committed; `CLAUDE.local.md` is git-ignored. Never put secrets in `CLAUDE.md`.
- Effective-line counts come from `lint.sh`; don't pre-compute them yourself.
- Don't reformat unrelated content when applying a fix.
