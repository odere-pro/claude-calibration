---
name: calibrate-rules
description: >-
  Audits and tunes every `.claude/rules/**/*.md` across user / project / plugin-self. Flags
  oversized files (> 200 effective lines), language- or area-specific rules missing `paths:`
  frontmatter (always-on context cost), plugin-shipped rules without `paths:` (load for every user
  who enables the plugin), broken globs, contradictions with CLAUDE.md, multi-step workflow bodies
  that should be a skill instead, and committed secrets. Also handles the `create` row when a
  recurring `claude-md:vague-rules` or `hook:exit-1-non-blocking` pattern needs a new path-scoped
  rule file scaffolded. Invoked by the calibration orchestrator (`/calibrate`) and standalone via
  `/claude-calibration:calibrate-rules`.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(bash *), Edit(.claude/rules/**), Edit(~/.claude/rules/**), Write(.claude/rules/**), Write(~/.claude/rules/**)
---

# calibrate-rules — per-feature bundle

You audit and tune `.claude/rules/` files. You receive one of two kinds of work:

- **Direct invocation** (`/claude-calibration:calibrate-rules`) — audit everything, report
  findings, propose fixes inline. The user drives the conversation.
- **Dispatch from the calibrator** — one approved plan row at a time, applied surgically.

In both cases the workflow is the same; only the framing differs.

## 1. Enumerate

```bash
bash <BUNDLE>/scripts/enumerate.sh "$PROJECT_DIR"
```

Yields TSV `scope\tpath`. Scope is `user` (`~/.claude/rules/...`), `project`
(`<PROJECT_DIR>/.claude/rules/...`), or `plugin-self` (`<plugin-root>/rules/...` when the project
itself is a plugin).

## 2. Lint

```bash
bash <BUNDLE>/scripts/lint.sh <path …>
```

Yields TSV `path\tsignature\tseverity\tdetail`. The signatures this bundle owns
(see `reference.md`):

- `rule:secret-leak` (CRITICAL)
- `rule:over-200` (MEDIUM)
- `rule:no-paths-when-language-specific` (MEDIUM)
- `rule:plugin-shipped-no-paths` (HIGH)
- `rule:bad-glob` (HIGH)
- `rule:contradicts-claude-md` (LOW)
- `rule:should-be-skill` (LOW)

## 3. Fix — `kind: edit` rows

For each finding, the remediation pattern is in `examples/<case>/`:

- `rule:over-200` → `examples/over-200/{before,after}.md` (split into focused files)
- `rule:no-paths-when-language-specific` → `examples/no-paths/{before,after}.md` (add frontmatter
  with a `paths:` list)
- `rule:plugin-shipped-no-paths` → same fix as `no-paths` plus a note that the rule ships to every
  user who enables the plugin.
- `rule:secret-leak` → remove the secret, rotate it, add to `.gitignore` or move to `.local`.
- `rule:bad-glob` → fix the YAML list shape.
- `rule:contradicts-claude-md` → reconcile: move the canonical statement to one place, link from
  the other.
- `rule:should-be-skill` → propose a new skill at `.claude/skills/<name>/SKILL.md`; remove the
  rule file or leave it as a one-line pointer.

## 4. Create — `kind: create` rows

When the planner detects a recurrence that this bundle owns (per `rules/dispatch.md`):

- **`claude-md:vague-rules` ×N** → scaffold a path-scoped rule at
  `.claude/rules/conventions.md` listing the canonical wordings (uses
  `templates/rule.md.tmpl`).
- **`hook:exit-1-non-blocking` ×N** → scaffold a doc-rule at
  `.claude/rules/hook-conventions.md` codifying "use `exit 2` to block, `exit 0` to pass,
  `exit 1` only for non-blocking warnings".

For both, copy `templates/rule.md.tmpl`, fill in `name`, `description`, `paths:`, and the body.

## 5. Verify

After every edit or create, re-run `bash <BUNDLE>/scripts/lint.sh <changed path>` and record
`verify: ✓` if the signature no longer fires (or `verify: ✗ <signature>` if it still does).

## Hard rules

- Never write a rule **without** `paths:` frontmatter unless the rule is genuinely universal (in
  which case its content belongs in CLAUDE.md, not `.claude/rules/`).
- Plugin-shipped rules (under `<plugin-root>/rules/`) MUST have `paths:` — they load for every
  user who enables the plugin.
- Don't reformat unrelated content in a rule file when applying a fix.
- Effective-line counts come from `lint.sh`; don't pre-compute them yourself.
