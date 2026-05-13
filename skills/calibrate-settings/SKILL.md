---
name: calibrate-settings
description: >-
  Calibrate every settings.json in this Claude Code setup — across user (~/.claude/settings.json,
  .local), project (.claude/settings.json, .local), managed-policy (read-only flag), and the relevant
  bits of ~/.claude.json. Flags committed secrets, --dangerously-skip-permissions traces, blanket
  destructive permissions allows, hard-pinned models in committed settings, env bloat, and
  precedence surprises (a project value overridden by managed). Either elevates an existing settings
  file or scaffolds a project settings.json from templates/settings.json.tmpl. Side-effecting; only
  you can invoke it (/claude-calibration:calibrate-settings).
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, TodoWrite
---

# calibrate-settings

You are the **settings calibrator**. Make every `settings.json` match `reference.md`: secrets in
`.local`-only, narrow `permissions` allow rules, sensible defaults, no destructive blanket-allow.

## Workflow

1. **Assess** — `${CLAUDE_SKILL_DIR}/scripts/enumerate.sh [PROJECT_DIR]` finds every settings layer;
   `lint.sh` emits findings (`settings:secret-in-committed`, `settings:dangerously-skip-permissions`,
   `settings:permissions-blanket-destructive`, `settings:model-pinned-in-committed`,
   `settings:env-bloated`).
2. **Decide per finding** — `edit` (most common: move secret to `.local`, narrow a permission rule,
   unpin a model) or `create` from `templates/settings.json.tmpl` if the project lacks one.
3. **Execute** — preserve JSON formatting (use a 2-space indent; sort keys only if the existing file
   already does). For permission narrowing, prefer rule-syntax (`Bash(git *)`, `Edit(*.ts)`) over
   bare allowlists.
4. **Verify** — re-run `lint.sh`; for JSON validity, `python3 -c "import json,sys; json.load(open(sys.argv[1]))" <file>` (or `jq . <file> >/dev/null`).

## Output

```
Applied  <id>  <settings file>  — <change>  [verify: ✓|✗]
Created  <id>  <settings file>  — from template  [verify: ✓|✗]
Skipped  <id>  <reason>
```

## Hard rules

- **Allowed paths:** project `.claude/settings.json` and `.claude/settings.local.json`. User and
  managed are recommend-only when called from `/calibrate`.
- **Never** add `--dangerously-skip-permissions` anywhere.
- A secret in a committed file is **CRITICAL** — surface immediately and recommend rotation.
