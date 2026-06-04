# `workflows/` — shipped `Workflow` scripts

`Workflow`-tool scripts that ship with the `claude-calibration` plugin. Claude Code has **no native
plugin component type for workflows** (a plugin loads only `skills/`, `agents/`, `rules/`, `hooks/`,
`commands/`). So this directory ships the source, and the plugin's `SessionStart` hook
(`hooks/install-workflows.sh`) copies each `*.mjs` here into the **project's** `.claude/workflows/`
registry — where the `Workflow` tool / `/workflows` resolves named workflows — the first time you
open a session with the plugin enabled.

These are workflows, **not** skills: there is no `SKILL.md`, and they are invoked through the
`Workflow` tool (`/workflows`), not `/claude-calibration:<name>`.

Install behaviour (never clobbers your edits): copies when the project copy is missing, stays silent
when it is identical, and warns (without overwriting) when a present copy differs from the bundled
version. To pull a plugin update, delete the project copy and restart.

## `calibration-audit-parallel.mjs`

A read-only calibration audit that parallelizes the 9-feature fan-out at the orchestration layer.
Same result as `/claude-calibration:calibration-audit` (planner-init → baseline-eval → reports under
`.claude/calibration/<ts>/`), but the workflow issues a deterministic `parallel()` barrier over the
nine `calibration-feature-evaluator` workers, then hands the drafts to `calibration-evaluator` for
the merge + interactions + intent-flow synthesis (its Pass-1 steps 4–8). All writes stay inside the
run folder, so the shipped `audit-write-guard.sh` hook applies unchanged.

### Run it

Once the SessionStart hook has installed it (or inside this repo, where it's already in
`.claude/workflows/`):

```text
/workflows                       # pick "calibration-audit-parallel"
```

Or run a specific file directly:

```text
Workflow({ scriptPath: ".claude/workflows/calibration-audit-parallel.mjs" })
```

### Optional args

All auto-discovered when omitted (the no-arg form works inside the plugin repo):

| arg | meaning |
| --- | ------- |
| `projectDir` | absolute path to the project being audited (default: cwd) |
| `bundlesDir` | absolute path to the plugin `skills/` dir (default: discovered) |
| `docsDir` | absolute path to the plugin `docs/` dir (default: `<bundlesDir>/../docs`) |
| `pluginFilter` | canonical `include:..\|exclude:..\|scope:..` spec (default: all plugins) |
| `restart` | force a fresh run folder |

### Output

Returns `{ runFolder, pluginFilter, featuresDrafted, featuresFailed, summary }`. The full reports
(`eval-features-*.md`, `eval-interactions-*.md`, `eval-intent-flow-*.md`) and `plan.md` are written
under `runFolder`, where `/claude-calibration:calibration-diff` expects them.
