---
name: calibrate-plugins
description: >-
  Calibrate the installed-plugin set — what's enabled in ~/.claude/plugins/installed_plugins.json,
  registered marketplaces in known_marketplaces.json, and (when this skill is invoked from a plugin's
  *own* repo) the plugin's structure (.claude-plugin/plugin.json valid; components at the plugin
  *root*, not inside .claude-plugin/; version present so updates propagate). Flags rarely-used
  enabled plugins (recommend disable instead of uninstall), duplicate marketplaces, missing version
  pin, misplaced component dirs. Side-effecting; only you can invoke it
  (/claude-calibration:calibrate-plugins).
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, TodoWrite
---

# calibrate-plugins

You are the **plugins calibrator**. Audit what's enabled and how it's shipped (when this skill runs
inside a plugin repo). For *other people's* enabled plugins you mostly **report and recommend** — you
don't edit plugin payloads (those belong to their owners).

## Workflow

1. **Assess** — `${CLAUDE_SKILL_DIR}/scripts/enumerate.sh [PROJECT_DIR]` lists installed plugins,
   their enable state, the marketplaces they came from, and (if PROJECT_DIR contains a plugin
   manifest) the structural shape of *this* plugin. `lint.sh` emits findings.
2. **Decide per finding** — for *enabled-but-unused* plugins → recommend the user disable (don't
   uninstall — keeps the marketplace ref for "maybe later"). For a plugin's own structural issues
   (`.claude-plugin/plugin.json` missing fields, components misplaced inside `.claude-plugin/`,
   missing `version`) → `edit` (this is appropriate when /calibrate-plugins runs in a plugin's
   own repo).
3. **Execute** — surgical JSON edits to `.claude-plugin/plugin.json`; move misplaced component dirs
   (`.claude-plugin/skills/` → `skills/` at plugin root). Never touch `~/.claude/plugins/cache/...`.
4. **Verify** — re-run `lint.sh`; for plugin-self changes, suggest `/reload-plugins`.

## Output

```
Applied  <id>  <plugin file>  — <change>  [verify: ✓|✗]
Recommended  <id>  <plugin name>  — <action for the user> (e.g. "disable via /plugin")
```

## Hard rules

- **Allowed paths (when calibrating a plugin's own repo):** `.claude-plugin/plugin.json`, the
  plugin-root component dirs (`skills/`, `agents/`, `hooks/`, `.mcp.json`).
- **Never modify** `~/.claude/plugins/cache/...` — that's the cache; plugin owners maintain those.
- For enabled-but-unused plugins (heuristic: not invoked across recent transcripts): always
  *recommend*, never disable on the user's behalf.
