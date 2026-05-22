# CLAUDE.md — `.claude/skills`

## Scope

Author-only **maintenance skills** for developing this repo. They live under `.claude/` (this repo's
own project config), so they load only in an author session working in the repo — they are **never**
loaded for someone who installs the `claude-calibration` plugin. Do not confuse them with the
shipped `skills/calibrate*` bundles.

- `docs-status/` — read-only staleness report for the `docs/` rubric.
- `docs-update/` — refresh `docs/` against the official Claude Code docs (via the `docs-fetcher` agent).
- `plugin-update/` — realign the per-feature bundles' `reference.md` / `templates/` / `lint.sh` with
  the now-current `docs/`.

The companion worker is `.claude/agents/docs-fetcher.md` (fetches one page over the network).

## The maintenance loop

```
/docs-status   ──▶  which docs/ pages look stale (git age + Sources)
/docs-update   ──▶  docs-fetcher (one page/call) ▶ diff live facts ▶ edit docs/  (approval-gated)
/plugin-update ──▶  propagate changed facts into skills/calibrate-*/  (approval-gated, four-places rule)
```

## Invariants you must not break

- **`disable-model-invocation: true` on every skill here.** These mutate `docs/` or the bundles;
  Claude must never auto-fire them. The user runs them by name.
- **Narrow `allowed-tools`.** `docs-status` is read-only (no `Write`/`Edit`); `docs-update` scopes
  writes to `docs/**`; `docs-update` is the only one that may spawn `Agent` (the fetcher).
- **The fetcher fetches one page per call.** Don't fan it out in parallel — one page keeps each
  fetch bounded and the diff focused.
- **`/plugin-update` honours the signature contract.** A changed threshold renames a signature, which
  is the four-places update in [`../../rules/CLAUDE.md`](../../rules/CLAUDE.md). Never silently rename.
- **Neither skill bumps `plugin.json` or tags a release** — they propose; the author disposes.

## How to test this area

- `claude --plugin-dir .` → `/reload-plugins` → `/docs-status` (should list `docs/` pages with a
  `## Sources` block, with git age + a staleness flag).
- `bash tests/gates/run-all.sh` — G3/G4 don't scan `.claude/skills/`, but keep these skills
  frontmatter-clean and `disable-model-invocation: true` anyway, by hand.

## When in doubt

These maintenance skills exist because the README and `docs/install.md` promise them. Keep their
behaviour aligned with those promises; if you change what they do, update those references.
