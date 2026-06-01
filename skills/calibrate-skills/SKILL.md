---
name: calibrate-skills
description: >-
  Audits every `SKILL.md` across user / project / plugin-self / plugin-cache. Flags missing or
  vague frontmatter (`name`, `description`), descriptions that bust the 1,536-char routing budget,
  bodies over 500 lines, side-effecting verbs (deploy / commit / push / publish / release / delete
  / post) without `disable-model-invocation: true`, overlapping descriptions that confuse Claude's
  routing, over-broad `allowed-tools` (bare `Bash` / `Edit` / `Write`), and bare-CLI invocations
  that should be promoted to a 4-layer wrapper skill. Also scaffolds the wrapper skill when a
  `skill:cli-not-wrapped` or `mcp:no-skill-pair` recurrence fires. Invoked by the calibration
  orchestrator (`/calibrate`) and standalone via `/claude-calibration:calibrate-skills`.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(bash *), Bash(gh *), Edit(.claude/skills/**), Edit(~/.claude/skills/**), Write(.claude/skills/**), Write(~/.claude/skills/**)
---

# calibrate-skills — per-feature bundle

You audit and tune `SKILL.md` files. You receive one of two kinds of work:

- **Direct invocation** (`/claude-calibration:calibrate-skills`) — audit everything, report
  findings, propose fixes inline. The user drives the conversation.
- **Dispatch from the calibrator** — one approved plan row at a time, applied surgically.

In both cases the workflow is the same; only the framing differs.

## 1. Enumerate

```bash
bash <BUNDLE>/scripts/enumerate.sh "$PROJECT_DIR"
```

Yields TSV `scope\tpath`. Scope is `user` (`~/.claude/skills/**/SKILL.md`), `project`
(`$PROJECT/.claude/skills/**/SKILL.md`), or `plugin-self` (`$PROJECT/skills/**/SKILL.md` when
the project itself is a plugin, plus plugin-cache best-effort).

The `plugin-self` (cached + project-plugin) rows honour the `CALIBRATION_PLUGIN_FILTER` env var, so
a calibration run scoped with `/calibrate --plugins …` only audits the requested plugins' skills.

## 2. Lint

```bash
bash <BUNDLE>/scripts/lint.sh <path …>
```

Yields TSV `path\tsignature\tseverity\tdetail`. The signatures this bundle owns
(see `reference.md`):

- `skill:missing-name` (HIGH)
- `skill:missing-description` (HIGH)
- `skill:description-over-1536` (MEDIUM)
- `skill:vague-description` (MEDIUM)
- `skill:body-over-500` (MEDIUM)
- `skill:side-effecting-no-dmi` (HIGH)
- `skill:overlap` (MEDIUM)
- `skill:allowed-tools-broad` (LOW)
- `skill:name-over-64` (HIGH)
- `skill:cli-not-wrapped` (LOW)
- `skill:in-repo-only-ok` (INFO)

## 3. Fix — `kind: edit` rows

For each finding, the remediation pattern is in `examples/<case>/`:

- `skill:missing-name` / `:missing-description` → add the frontmatter field.
- `skill:description-over-1536` → trim the description; move detail into the body or `reference.md`.
- `skill:vague-description` → rewrite to include routing words ("use when", "after", "before").
- `skill:body-over-500` → split into `SKILL.md` (workflow) + `reference.md` (detail).
- `skill:side-effecting-no-dmi` → add `disable-model-invocation: true` so Claude can't auto-fire
  a destructive workflow.
- `skill:overlap` → reconcile descriptions; rename or merge the overlapping skills.
- `skill:allowed-tools-broad` → narrow to scoped permissions (`Bash(gh *)` not bare `Bash`).
- `skill:name-over-64` → rename to ≤ 64 chars (Claude hard-caps the field).
- `skill:cli-not-wrapped` → see `examples/cli-not-wrapped/`: add scoped `Bash(<tool> *)` to
  `allowed-tools` and `disable-model-invocation: true`. **Recurrence** for the same CLI promotes
  to a new wrapper skill (uses `templates/cli-wrapper.tmpl`).
- `skill:in-repo-only-ok` → informational; no action.

## 4. Create — `kind: create` rows

When the planner detects a recurrence that this bundle owns (per `rules/dispatch.md`):

- **`skill:cli-not-wrapped` ×N for the same CLI** → 3→4-layer promotion. Scaffold a wrapper skill
  at `.claude/skills/<cli>-wrapper/SKILL.md` using `templates/cli-wrapper.tmpl`.
- **`mcp:no-skill-pair` ×N for the same server** → scaffold an MCP wrapper skill at
  `.claude/skills/<server>-wrapper/SKILL.md` using `templates/mcp-wrapper.tmpl`.

Both templates include `disable-model-invocation: true` and narrow `allowed-tools` by default.

## 5. Verify

After every edit or create, re-run `bash <BUNDLE>/scripts/lint.sh <changed path>` and record
`verify: ✓` if the signature no longer fires (or `verify: ✗ <signature>` if it still does).

## Hard rules

- Side-effecting skills MUST have `disable-model-invocation: true` — Claude must never auto-fire
  a deploy / commit / publish workflow.
- `allowed-tools` is narrow by default. Bare `Bash` / `Edit` / `Write` is a code-smell.
- `description` + `when_to_use` combined must stay under 1,536 chars (Claude's routing budget).
- `name` ≤ 64 chars (hard cap).
- Body ≤ ~500 lines; reference belongs in `reference.md`.
- Don't reformat unrelated content when applying a fix.
