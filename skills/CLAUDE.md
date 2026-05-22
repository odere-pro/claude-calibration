# CLAUDE.md — `skills`

## Scope

The plugin's skill layer: the orchestrator, the dispatcher, four flows, and the nine per-feature
calibration bundles. All ship to end users; all are `disable-model-invocation: true` (zero standing
context — the user fires them by name).

- `calibrate/` — the `/calibrate` orchestrator (opus): the evaluate → plan → calibrate → re-evaluate loop.
- `calibration/` — the `/claude-calibration:calibration` dispatcher (menu / router).
- `calibration-{audit,diff,doctor,onboarding}/` — the four flows.
- `calibrate-{claude-md,rules,settings,skills,subagents,hooks,mcp,plugins,general}/` — the nine bundles.

## Map — every `calibrate-<feature>` bundle ships the same layout

```
skills/calibrate-<feature>/
├── SKILL.md          # frontmatter MUST include disable-model-invocation: true
├── reference.md      # Must / Should / Limits / Pattern signatures (cites docs/features/<feature>.md)
├── scripts/
│   ├── enumerate.sh  # list instances → TSV: scope\tpath
│   └── lint.sh       # audit instances → TSV: path\tsignature\tseverity\tdetail
├── templates/<artifact>.tmpl   # ≥ 1, for kind:create rows
└── examples/<case>/{before,after}.md   # ≥ 1, for kind:edit rows
```

Gate **G7** (`tests/gates/07-signature-dispatch-integrity.sh`) enforces this layout for all nine.

## Invariants you must not break

- **`disable-model-invocation: true`** on every shipped skill (gate G4). Non-negotiable.
- **`name` + `description` frontmatter** present (gate G3); narrow `allowed-tools` (no bare
  `Bash`/`Write`/`Edit`).
- **Bundle layout is the contract.** A bundle missing `reference.md`, a `scripts/{enumerate,lint}.sh`,
  a template, or an example fails G7.
- **`lint.sh` emits signatures verbatim** from [`../rules/signatures.md`](../rules/signatures.md) — a
  typo'd signature is invisible to the planner's recurrence detector. See
  [`../rules/CLAUDE.md`](../rules/CLAUDE.md).
- **The nine features are fixed.** Adding/removing a `calibrate-*` bundle means updating G7's expected
  set and `../rules/dispatch.md`.

## Editing checklist

- [ ] Frontmatter parses; `disable-model-invocation: true`; `allowed-tools` scoped.
- [ ] If you touched a signature, the four-places update (see `../rules/CLAUDE.md`).
- [ ] `bash skills/calibrate-<feature>/scripts/lint.sh` still emits cleanly on its own examples.
- [ ] `bash tests/gates/run-all.sh` green.

## How to test this area

- `claude --plugin-dir .` → `/reload-plugins` → `/claude-calibration:calibration-audit` (read-only
  end-to-end) and `/calibrate cost` (load-bearing on `calibrate-general/scripts/lint.sh`).
- `bash tests/gates/07-signature-dispatch-integrity.sh` — bundle layout + signature/dispatch integrity.

## When in doubt

House rules: [`../.claude/rules/plugin-dev.md`](../.claude/rules/plugin-dev.md). A worked example of a
bundle: `calibrate-skills/` (`reference.md` + `scripts/lint.sh`).
