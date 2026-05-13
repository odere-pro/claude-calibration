[← README](README.md) · [Usage](usage.md) · [Glossary](glossary.md) · [General setup](general-setup.md)

# Install — `claude-calibration`

How to install, verify, enable, disable, update, and uninstall the `claude-calibration` plugin. All
plugin lifecycle is handled by Claude Code's built-in `/plugin` command (see
[`features/plugins.md`](features/plugins.md) for the underlying mechanics); this page lists the
specific invocations for this plugin.

## What gets added when the plugin is enabled

- **1 user-invocable orchestrator skill** — `/calibrate` (the entry point; `disable-model-invocation: true`).
  Three convenience modes are built into `/calibrate`'s argument parser (no separate skills): `/calibrate
  tighten`, `/calibrate harden`, `/calibrate cost`.
- **1 user-invocable dispatcher** — `/calibration` (menu / shortcut over the orchestrator;
  `disable-model-invocation: true`).
- **2 convenience flow skills** — `/claude-calibration:calibration-audit` and `-diff` (slim
  orchestrators that spawn their own subagent chain; `disable-model-invocation: true`).
- **9 per-feature calibration skills** — `/claude-calibration:calibrate-{claude-md, rules, settings,
  skills, subagents, hooks, mcp, plugins, general}` (each `disable-model-invocation: true`).
- **3 worker subagents** — `calibration-planner`, `calibration-evaluator`, `calibration-calibrator`
  (only invoked by the orchestrator; their `name + description` is the only standing cost).
- **2 path-scoped rules** — `rules/signatures.md`, `rules/dispatch.md` — load only when files under
  `.claude/calibration/**` or `skills/calibrate-*/**` are open. Zero cost in normal sessions.
- **2 safety hooks** — `PreToolUse` write-guards scoped to the calibrator subagent and to the
  audit-only flow. Zero cost unless the matchers fire.

Because every shipped skill carries `disable-model-invocation: true`, the **standing context cost
when idle is ~zero** — the descriptions are removed from context and Claude can never auto-fire
them. Run `/context` after enabling to confirm.

## Install

### Via a marketplace (recommended)

```text
/plugin marketplace add <marketplace-url-or-repo>     # if you haven't already
/plugin install claude-calibration@<marketplace>
```

`/plugin` opens an interactive browser; once installed it is enabled in this scope (user-wide by
default).

### Via a local directory (for development or one-shot use)

```bash
claude --plugin-dir /path/to/claude-calibration
```

Loads the plugin for this session only. The local copy wins if a same-name plugin is also installed.
After editing under `--plugin-dir`, run `/reload-plugins` to pick up the changes (a brand-new
top-level `skills/` directory needs a full restart).

### Via a URL (for CI or distributed builds)

```bash
claude --plugin-url https://example.com/claude-calibration.zip
```

Fetches a packaged plugin for one session. If the fetch fails Claude reports a load error and starts
without the plugin.

## Verify the install

In a Claude Code session after installing:

```text
/plugin                 # lists installed plugins + which marketplace; confirms claude-calibration is enabled
/skills                 # confirms /calibrate, /calibration, /claude-calibration:* are registered; press t to sort by token cost
/agents                 # confirms the three calibration-* workers are registered
/context                # confirms the plugin adds ~zero standing context cost when idle
```

Expected after install (idle session):

- `/skills` shows the 13 plugin skills (`/calibrate`, `/calibration`, 2 convenience flows, 9
  per-feature bundles) **with their token costs collapsed to ~0** — they are
  `disable-model-invocation: true` so their descriptions are removed from context. The three
  built-in modes (`tighten` / `harden` / `cost`) are arguments to `/calibrate`, not separate skills.
- `/agents` shows the three workers; they do not contribute standing cost (Claude only sees their
  name+description when routing a subagent task).
- `/context` shows no measurable bump from this plugin.

## Enable / disable

Disable preserves the install for "maybe later"; uninstall removes it.

```text
/plugin disable claude-calibration              # turn off without removing
/plugin enable  claude-calibration              # turn back on
/plugin uninstall claude-calibration            # remove entirely
```

When the plugin is disabled, none of its skills/subagents/hooks/rules load. The hidden
`.claude/calibration/` run state (if any) is left in place — it lives in the project repo, not in
the plugin.

## Update

| Scenario | What to run |
|---|---|
| You're developing the plugin under `--plugin-dir` and just edited a SKILL.md / agent / lint script. | `/reload-plugins` (the orchestrator picks up the edit immediately). |
| You added a **brand-new** top-level directory (e.g. a new bundle under `skills/`). | Restart the session. |
| You bumped `.claude-plugin/plugin.json` `version` and pushed to the marketplace. | Marketplace users next-pull via `/plugin update claude-calibration@<marketplace>`. |
| The plugin's *rubric* drifts from upstream (the official Claude Code docs). | Run `/docs-update` (re-fetches `docs/features/*.md` from `code.claude.com/docs/*`) and then `/plugin-update` (realigns the per-feature bundles' `reference.md` / `templates/` / `scripts/lint.sh` to the now-current `docs/`). These are maintenance skills shipped under `.claude/skills/`, not under the plugin payload. |

## Removing run artifacts

`/calibrate` writes run state to `<project>/.claude/calibration/<timestamp>/`. The plugin **does
not** remove this when you uninstall — it's your project's data.

```bash
# Archive a single run
mv .claude/calibration/2025-01-15-1042 ~/calibration-archives/

# Delete all runs in this project
rm -rf .claude/calibration/

# Prevent future runs from being committed
echo '.claude/calibration/' >> .gitignore
```

The calibrator offers to append `.claude/calibration/` to `.gitignore` on the first run if it isn't
already there.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `/calibrate` not in the skill list. | Plugin not enabled, or not loaded yet. | `/plugin` to confirm it's enabled; `/reload-plugins` if you just installed it; restart if you added the plugin via a new top-level `skills/` dir. |
| `/context` shows the plugin costing thousands of tokens when idle. | The `disable-model-invocation` frontmatter didn't load — check that you're on the marketplace-installed version (not a stale fork). | `/plugin uninstall claude-calibration && /plugin install claude-calibration@<marketplace>`. |
| `/calibrate` complains it can't read `docs/` or `BUNDLES_DIR=UNKNOWN`. | The plugin's `${CLAUDE_SKILL_DIR}` resolution failed (rare; usually a packaging issue). | Run the orchestrator with `--plugin-dir` for one session to confirm the layout is what's on disk; if it works there, reinstall via the marketplace. |
| The calibrator wrote outside the expected paths. | The shipped safety hooks didn't load. | Confirm `hooks/hooks.json` is present in your installed copy; `/hooks` will list every active hook — the two `claude-calibration` entries should appear. |

## Sources

- Plugin layout, manifest, lifecycle, `/plugin`, `--plugin-dir`, `--plugin-url`, `/reload-plugins` — [`features/plugins.md`](features/plugins.md) (and its upstream sources: <https://code.claude.com/docs/en/plugins>).
- `/skills` / `/agents` / `/context` / `/doctor` — [`general-setup.md`](general-setup.md).
- Hooks (`PreToolUse`, scoping, exit codes) — [`features/hooks.md`](features/hooks.md).
