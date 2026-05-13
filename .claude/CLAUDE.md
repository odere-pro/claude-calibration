# claude-calibration — repo notes

This repo **is** the `claude-calibration` plugin (manifest: `.claude-plugin/plugin.json`).

- `docs/` is the **rubric**: a doc-set grounded in the official Claude Code docs. Every page has a
  `## Sources` section listing its `code.claude.com/docs/*` URLs. **Edit `docs/` only with grounding in
  those sources.** Preserve each page's template (`Definition` · `Scope` · `Configure` · `Validate` ·
  `Improve` · `Sources`) and the DRY rule — a fact lives on exactly one page; other pages link to it.
- Plugin code: `skills/calibrate/SKILL.md` (the `/calibrate` orchestrator) and
  `agents/calibration-{planner,evaluator,calibrator}.md`. Keep subagent bodies focused (≲200 lines),
  `tools:` minimal and explicit, `model:` explicit. `/calibrate`, and the maintenance skills below, are
  `disable-model-invocation: true` (side-effecting).
- On any change to the plugin's *shipped* components (`skills/`, `agents/`, `.claude-plugin/plugin.json`),
  bump `version` in the manifest. After editing under `--plugin-dir`, run `/reload-plugins`.
- Maintenance workflow (these live in `.claude/skills/`, not shipped): `/docs-status` → `/docs-update`
  → `/plugin-update`. They use the `docs-fetcher` subagent and need `WebFetch(domain:code.claude.com)`
  (allowed in `.claude/settings.json`).
- Don't commit `.claude/calibration/` (it's gitignored — `/calibrate` writes run state there).
