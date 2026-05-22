# Contributing to `claude-calibration`

Thanks for helping improve the plugin. This is a **pure-content Claude Code plugin** — Markdown
(skills, agents, rules, docs) plus a few Bash scripts. There is no build step and no compiled code.

The authoritative house rules live in [`.claude/rules/plugin-dev.md`](.claude/rules/plugin-dev.md)
and [`CLAUDE.md`](CLAUDE.md); this file is the contributor-facing summary.

## Dev loop

Load the local checkout as a plugin and exercise it against itself:

```bash
claude --plugin-dir .
```

Then, inside the session:

```text
/reload-plugins                              # pick up edits to skills / agents / lint scripts
/claude-calibration:calibration-audit        # read-only end-to-end smoke (no edits)
/calibrate cost                              # load-bearing on calibrate-general/scripts/lint.sh
/calibrate "audit this plugin's setup"       # dogfood: calibrate the plugin against its own rubric
```

A brand-new top-level `skills/` directory needs a full restart, not just `/reload-plugins`.

## Run the gates

Before opening a PR, run the validation suite (needs `jq` and `shellcheck`):

```bash
bash tests/gates/run-all.sh
```

CI runs the same suite on every push and pull request (see
[`.github/workflows/ci.yml`](.github/workflows/ci.yml)). A CRITICAL gate failing blocks merge;
advisory gates (e.g. markdown style) only warn. The gates are documented in
[`tests/gates/`](tests/gates/) — each is a small standalone script.

## The signature contract (read before touching findings)

Pattern signatures (`<feature>:<short-name>`, e.g. `subagent:missing-tools`) are part of the
public contract — renaming one breaks cross-run recurrence history. Adding or changing a signature
means keeping **four** places in sync:

1. `rules/signatures.md` — the canonical catalogue.
2. the owning bundle's `reference.md` — its "Pattern signatures" section.
3. the owning bundle's `scripts/lint.sh` — the emit.
4. `rules/dispatch.md` — if it has a `kind: create` (recurrence) archetype.

Gate **G7** (`tests/gates/07-signature-dispatch-integrity.sh`) enforces the dispatch ↔ catalogue
half of this. See `.claude/rules/plugin-dev.md` for the full rule.

## Bundle layout

Every `skills/calibrate-<feature>/` ships `SKILL.md` (with `disable-model-invocation: true`),
`reference.md`, `scripts/{enumerate,lint}.sh`, at least one `templates/*.tmpl`, and at least one
`examples/<case>/` pair. Gate G7 checks this for all nine features.

`disable-model-invocation: true` is non-negotiable on every shipped skill — Claude must never
auto-fire a calibration skill (gate G4).

## Branches and commits

- **Branches**: `feat/<slug>`, `docs/<slug>`, `fix/<slug>`, or `calibrate/<slug>` (matching the
  existing history).
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org) —
  `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `ci:`.
- For any user-visible change, add a `changelog/<NN>-<slug>.md` fragment (one bullet, no SHA prefix)
  rather than editing `CHANGELOG.md` directly — see [`changelog/README.md`](changelog/README.md).
  Doc-only PRs may skip it; gate G16 (`16-changelog-fragment-present.sh`) encodes the rule.

## Releasing

Maintainers only — see [`docs/RELEASING.md`](docs/RELEASING.md).
