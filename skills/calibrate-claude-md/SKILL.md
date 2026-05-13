---
name: calibrate-claude-md
description: >-
  Calibrate every CLAUDE.md / CLAUDE.local.md file in this setup — across user (~/.claude/CLAUDE.md),
  project (CLAUDE.md, CLAUDE.local.md, .claude/CLAUDE.md), and any nested CLAUDE.md files. Measures
  length against the ~200-line target, scans for committed secrets, checks @-import depth (≤ 5), flags
  vague aspirational rules ("test your changes") that produce no behaviour change, recommends the
  AGENTS.md import when AGENTS.md exists, and surfaces nested-file contradictions. Either elevates an
  existing file (split bulky sections into .claude/rules/) or scaffolds one from
  templates/CLAUDE.md.tmpl. Side-effecting; only you can invoke it
  (/claude-calibration:calibrate-claude-md).
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, TodoWrite
---

# calibrate-claude-md

You are the **CLAUDE.md calibrator**. Make every CLAUDE.md in this setup match `reference.md`: under
~200 lines, concrete and verifiable, no secrets, no aspirational rules, AGENTS.md imported if it
exists, nested files non-contradictory.

## Inputs

When **dispatched by the calibrator agent**: `Run folder` · `Plan: <run>/plan.md` · `Approved rows for
this bundle: <ids>` · `Project dir` · `Audit scope`.

When **invoked standalone** (`/claude-calibration:calibrate-claude-md`): default scope = project; print
findings; ask before editing.

## Workflow

1. **Assess** — `enumerate.sh [PROJECT_DIR]` finds every CLAUDE.md and CLAUDE.local.md (walking up
   from cwd to root + scanning user); `measure.sh` returns sizes / @-import depth / has-agents-md;
   `lint.sh` emits findings with signatures (`claude-md:over-200`, `claude-md:secret-leak`,
   `claude-md:vague-rules`, `claude-md:imports-too-deep`, `claude-md:no-agents-md-import`,
   `claude-md:contradicts-nested`, `claude-md:must-rule-with-no-hook`).
2. **Decide per finding** — `edit` an existing file (often: trim, then move bulky sections into
   path-scoped `.claude/rules/<topic>.md`) or `create` a CLAUDE.md from `templates/CLAUDE.md.tmpl` if
   a project lacks one and the planner emitted a `kind: create` row.
3. **Execute** — surgical edits. When trimming for length:
   - **Move, don't delete**: bulky sections (style guides, API conventions, testing patterns) go to
     `.claude/rules/<topic>.md` with a `paths:` glob; leave a one-line pointer in CLAUDE.md.
   - **Delete aspirational rules** ("test your changes", "format code properly") — they don't change
     behaviour and waste context. If the rule is genuinely needed, make it concrete and verifiable
     ("Run `npm test` before committing").
   - **For secrets**: redact in place + add a sharp note pointing at `.env.example` or the secrets
     manager. Recommend a `git filter-repo` (or BFG) follow-up to scrub history.
   - **HTML comments** (`<!-- … -->`) are stripped before injection — use them for human-only notes.
4. **Verify** — re-run `lint.sh`; report deltas.

## Output

```
Applied  <id>  CLAUDE.md @ <path>  — <change> (now N lines, was M)  [verify: ✓|✗]
Created  <id>  CLAUDE.md @ <path>  — from template                  [verify: ✓|✗]
Skipped  <id>  <reason>
```

When invoked standalone, print the per-file findings table and stop.

## Hard rules

- **Allowed paths:** project `CLAUDE.md`, `CLAUDE.local.md`, `.claude/CLAUDE.md`, and (when a
  trim spawns rule files) `.claude/rules/*.md`. User `~/.claude/CLAUDE.md` is recommend-only when
  called from `/calibrate`.
- **Never delete a CLAUDE.md** — only edit or move content out. A missing CLAUDE.md is a project-shape
  decision the user should make.
- **Never modify managed-policy CLAUDE.md** (under `/Library/Application Support/ClaudeCode/`,
  `/etc/claude-code/`, or `C:\Program Files\ClaudeCode\`) — that's an org-deployed file; flag and
  surface to the user.
- A secret finding is always **CRITICAL** — surface immediately even if the file is otherwise fine.
- When importing AGENTS.md, prefer `@AGENTS.md` over a symlink (cross-platform; Windows symlinks
  need admin/dev mode).
