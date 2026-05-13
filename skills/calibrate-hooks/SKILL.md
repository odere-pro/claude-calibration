---
name: calibrate-hooks
description: >-
  Calibrate every hook in this Claude Code setup — the `hooks` block in user/project/local
  settings.json files, plus standalone hook scripts under .claude/hooks/. Flags broad matchers on
  hot events (`*` on PreToolUse), exit-1-non-blocking misuse, untrusted remote execution from a hook,
  duplicates across layers, and slow-on-PreToolUse heuristics. Either elevates an existing hook
  (narrow matcher, fix exit code) or scaffolds a new one (e.g. an enforcement hook the planner
  promoted from a recurring finding) from templates/hooks.json.tmpl. Side-effecting; only you can
  invoke it (/claude-calibration:calibrate-hooks).
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, TodoWrite
---

# calibrate-hooks

You are the **hooks calibrator**. Make every hook in this setup match `reference.md`: narrow
matcher, locally-sourced handler, `exit 2` for enforcement (NOT `exit 1`), heavy work on `Stop`
(not `PreToolUse`), single digits in count.

## Workflow

1. **Assess** — `${CLAUDE_SKILL_DIR}/scripts/enumerate.sh [PROJECT_DIR]` lists every hooks-bearing
   layer; `lint.sh` parses each `hooks` block + every script under `.claude/hooks/` and emits
   findings (`hook:matcher-bare-star`, `hook:exit-1-non-blocking`, `hook:remote-untrusted`,
   `hook:duplicate-across-layers`, `hook:heavy-on-pretooluse-heuristic`).
2. **Decide per finding** — `edit` (narrow the matcher; fix the exit code; move heavy work to `Stop`)
   or `create` (especially: planner-promoted *enforcement* hooks — a `PreToolUse` hook that fails
   when a subagent file lacks `tools:`, etc.) from `templates/hooks.json.tmpl` + a script in
   `.claude/hooks/`.
3. **Execute** — surgical JSON edits (the `hooks` block in `settings.json`) + script writes (chmod
   +x; reference via `${CLAUDE_PROJECT_DIR}/.claude/hooks/<script>`).
4. **Verify** — re-run `lint.sh`; for the JSON, `jq . <file>` (or `python3 -m json.tool <file>`).

## Output

```
Applied  <id>  <hooks block @ file>  — <change>  [verify: ✓|✗]
Created  <id>  <hook>  @ <file> + <script>  [verify: ✓|✗]
Skipped  <id>  <reason>
```

## Hard rules

- **Allowed paths:** project `.claude/settings.json`'s `hooks` block, project `.claude/hooks/**`, and
  `.claude/settings.local.json`'s `hooks` block. User-scope is recommend-only when called from
  `/calibrate`.
- Never wire a hook to `curl|wget|npx <remote>` — use project-owned scripts only.
- Use `exit 2` (or JSON `permissionDecision: deny`) for enforcement. `exit 1` does NOT block.
- Heavy work (full builds, full test runs) goes on `Stop`, NOT `PreToolUse`/`PostToolUse`.
