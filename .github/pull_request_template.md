## What

<!-- One paragraph, plain English: what does this change do? -->

## Why

<!-- Issue link + rationale. -->

## Checklist

- [ ] `bash tests/gates/run-all.sh` passes locally
- [ ] Ran `/claude-calibration:calibration-audit` (read-only end-to-end smoke) under `--plugin-dir .`
- [ ] Added a `changelog/<NN>-<slug>.md` fragment for any user-visible change (or the change is
      doc-only — see `changelog/README.md`; gate G16 enforces this)
- [ ] If a pattern signature changed: updated all four places — `rules/signatures.md`, the bundle's
      `reference.md`, the bundle's `scripts/lint.sh`, and `rules/dispatch.md`
- [ ] If a bundle changed: it still ships `SKILL.md` (`disable-model-invocation: true`),
      `reference.md`, `scripts/{enumerate,lint}.sh`, ≥1 template, ≥1 example
- [ ] Docs updated and intra-doc links resolve (gate G14)

## Out of scope

<!-- Anything deliberately deferred, with a one-line reason. -->
