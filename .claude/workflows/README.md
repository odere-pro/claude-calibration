# `.claude/workflows/` — shipped `Workflow` scripts

`Workflow`-tool scripts that ship with the `claude-calibration` plugin. Claude Code only auto-*loads*
`skills/`, `agents/`, `rules/`, `hooks/`, `commands/` from a plugin — never a `workflows/` dir — but
the whole repo is cloned into the plugin cache, so these files **are** installed and runnable by the
`Workflow` tool. These are workflows, **not** skills: there is no `SKILL.md`, and they are invoked
through `Workflow`, not `/claude-calibration:<name>`.

## `calibration-audit-parallel.mjs`

A read-only calibration audit that parallelizes the 9-feature fan-out at the orchestration layer.
Same result as `/claude-calibration:calibration-audit` (planner-init → baseline-eval → reports under
`.claude/calibration/<ts>/`), but the workflow issues a deterministic `parallel()` barrier over the
nine `calibration-feature-evaluator` workers, then hands the drafts to `calibration-evaluator` for
the merge + interactions + intent-flow synthesis (its Pass-1 steps 4–8). All writes stay inside the
run folder, so the shipped `audit-write-guard.sh` hook applies unchanged.

### Run it

Plugin authors (inside this repo) — it's in the named-workflow registry:

```text
/workflows                       # pick "calibration-audit-parallel"
```

End users (plugin installed) — run the cache copy by path:

```text
Workflow({ scriptPath: "<plugin-cache>/claude-calibration/.claude/workflows/calibration-audit-parallel.mjs" })
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
