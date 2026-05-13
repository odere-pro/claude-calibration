---
name: plugin-update
description: >-
  Realign this plugin's own components (skills/calibrate, agents/calibration-*, .claude-plugin/plugin.json,
  the maintenance skills) with the current docs/ and any new Claude Code features — deprecated frontmatter,
  new frontmatter keys, new hook events/commands, changed limits, new manifest fields. Proposes a
  plugin.json "version" bump and waits for approval before writing it. Side-effecting; only you can run
  it (/plugin-update). Run /docs-update first so docs/ is current.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent, TodoWrite
---

# plugin-update — keep the plugin in step with Claude Code

You bring this plugin's *own* files in line with the current `docs/` rubric and the latest Claude Code
conventions. Assume `docs/` is up to date (recommend `/docs-update` first if it isn't, or run a couple
of `docs-fetcher` checks on the pages most relevant below).

## Do

1. Re-read the relevant `docs/` pages — especially `features/skills.md`, `features/subagents.md`,
   `features/plugins.md`, `features/hooks.md`, `features/commands.md`, and `general-setup.md` (their
   **Improve** sections + limits tables + any new feature mentioned). If anything there is uncertain,
   `Agent(docs-fetcher)` on that page's Sources URL to confirm.
2. Review and update each plugin component against current best practice:
   - `.claude-plugin/plugin.json` — manifest schema current? all useful fields present (`name`,
     `description`, `version`, `author`, `homepage`, `license`, `keywords`)? `description` still accurate?
   - `skills/calibrate/SKILL.md` — frontmatter keys still valid and not deprecated (`disable-model-invocation`,
     `model`, `allowed-tools`, `argument-hint`, the `` ```! `` block)? any new key worth adopting? body
     still concise? does it reference commands/behaviours that changed?
   - `agents/calibration-{planner,evaluator,calibrator}.md` — `tools:` minimal and explicit?
     `model:` explicit and still the right choice? bodies focused (≲200 lines)? `maxTurns` on the
     calibrator still sensible? any new subagent frontmatter (e.g. isolation/effort/memory) worth using?
     do their instructions still match how features behave (file locations, frontmatter, limits)?
   - **The 9 per-feature bundles** at `skills/calibrate-<feature>/` (`claude-md`, `rules`, `settings`,
     `skills`, `subagents`, `hooks`, `mcp`, `plugins`, `general`):
     - `reference.md` — distil the matching `docs/features/<feature>.md` (or `docs/general-setup.md`
       for `calibrate-general`): Must / Should / Limits / pattern signatures / 3-vs-4-layer call
       (where applicable). If the source doc gained or lost a Must/limit/signature, propagate it
       here; keep the link back to the source.
     - `templates/` — when a doc adds or renames a frontmatter key (e.g. a new `effort:` field, a
       renamed `disable-model-invocation`), update the matching template (`SKILL.md.tmpl`,
       `subagent.md.tmpl`, `cli-wrapper.tmpl`, `mcp-wrapper.tmpl`, `CLAUDE.md.tmpl`,
       `hooks.json.tmpl`, `rule.md.tmpl`, etc.) and the corresponding `examples/<case>/after.md`.
     - `scripts/lint.sh` — when the doc changes a numeric limit (e.g. description char cap, body
       line target), update the constants at the top of the script and the signature names in the
       output (and in `reference.md`'s table).
     - `SKILL.md` — keep the workflow shape and the cross-bundle handoffs accurate (e.g. `calibrate-mcp`
       → `calibrate-skills` for the wrapper-skill creation).
   - `.claude/agents/docs-fetcher.md` and `.claude/skills/{docs-status,docs-update,plugin-update}` —
     same checks; keep them consistent with the doc-set's voice and current frontmatter.
3. Apply the updates surgically (don't reformat files wholesale).
4. **Version bump:** decide a semver bump for `.claude-plugin/plugin.json` (`patch` = doc-sync / fixes,
   `minor` = new capability or notable behaviour change, `major` = breaking change to how `/calibrate`
   works). **Show the proposed `version` (old → new) and the reason, and ask the user to confirm before
   you write `plugin.json`.** If they decline, leave the version as-is.
5. Summarize: which component files changed and the headline change in each; the version decision; and
   `Run /reload-plugins to pick up the changes (a brand-new top-level skills/ dir needs a restart).`

## Don't

- Don't touch `docs/` here (that's `/docs-update`) and don't touch the user's setup.
- Don't change behaviour the docs don't call for; this is a sync pass, not a redesign.
- Don't bump `version` without the user's OK.
