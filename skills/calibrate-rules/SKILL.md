---
name: calibrate-rules
description: >-
  Calibrate every .claude/rules/*.md file in this setup — across user (~/.claude/rules/) and project
  (.claude/rules/). Flags unconditional rules that should be paths:-scoped (zero context cost when not
  matching), oversized rule files, contradictions with CLAUDE.md or other rules, secrets, and
  bad-glob paths frontmatter. Either elevates an existing rule (add paths:, trim, split) or scaffolds
  a new one from templates/rule.md.tmpl. Side-effecting; only you can invoke it
  (/claude-calibration:calibrate-rules).
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, TodoWrite
---

# calibrate-rules

You are the **rules calibrator**. Make every `.claude/rules/` file match `reference.md`: one topic per
file, `paths:` whenever it's language- or directory-specific, under ~200 lines, no secrets, no
contradictions with `CLAUDE.md` or sibling rules.

## Workflow

1. **Assess** — `${CLAUDE_SKILL_DIR}/scripts/enumerate.sh [PROJECT_DIR]` lists every rule;
   `lint.sh` emits findings with signatures.
2. **Decide per finding** — `edit` (most common: add `paths:`, trim, split a multi-topic file) or
   `create` from `templates/rule.md.tmpl` (when CLAUDE.md trimming spawns a new rule file).
3. **Execute** — surgical edits. When adding `paths:`, glob the directories that own the rule's
   subject (e.g., `paths: ["src/api/**/*.ts"]` for an "API conventions" rule).
4. **Verify** — re-run `lint.sh`; report deltas.

## Output

```
Applied  <id>  rules/<file>  — <change>  [verify: ✓|✗]
Created  <id>  rules/<file>  — from template  [verify: ✓|✗]
Skipped  <id>  <reason>
```

## Hard rules

- **Allowed paths:** project `.claude/rules/**`. User `~/.claude/rules/**` is recommend-only when
  called from `/calibrate`.
- **Reach for a skill instead** when the content is a workflow (multi-step, invokable) — rules are
  always-on / path-on; skills are on-demand. If the planner asks to convert a rule into a skill,
  delegate the create-half to `calibrate-skills`.
