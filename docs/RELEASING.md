[← docs README](README.md) · [Install](install.md) · [Changelog](../CHANGELOG.md)

# Releasing `claude-calibration`

This is a Claude Code **plugin**, distributed through a marketplace — not npm. A "release" is a git
tag plus a GitHub Release; marketplace consumers update by re-pulling the tagged commit. The version
of record is `.claude-plugin/plugin.json` → `version` (the marketplace entry deliberately omits
`version` so there is one source of truth).

## Before you tag

1. **Bump the version** in `.claude-plugin/plugin.json`. Use [SemVer](https://semver.org):
   - patch — doc fixes, lint-script tweaks, no behaviour change;
   - minor — a new bundle / flow / signature, backward-compatible;
   - major — a renamed signature or a breaking change to the run-folder/plan contract.
2. **Aggregate the changelog fragments**, then cut the version section:

   ```bash
   bash scripts/changelog-aggregate.sh           # dry-run: preview the fragment bullets
   bash scripts/changelog-aggregate.sh --apply    # inline them under [Unreleased] ### Added, remove fragments
   ```

   Then move the now-complete `[Unreleased]` items into a new `## [X.Y.Z] — YYYY-MM-DD` section and
   refresh the compare links at the bottom. (Per-PR fragments live under `changelog/`; see
   [`../changelog/README.md`](../changelog/README.md).)
3. **Reconcile any count text** in `docs/install.md` and `README.md` if you added or removed a skill
   / agent / bundle (e.g. the "15 plugin skills" line).
4. If you added a signature, confirm it is in sync across all four places (`rules/signatures.md`,
   the owning bundle's `reference.md`, its `scripts/lint.sh`, and `rules/dispatch.md`) — gate G7
   checks the dispatch ↔ catalogue half of this.
5. **Run the gates locally:**

   ```bash
   bash tests/gates/run-all.sh
   ```

6. **Smoke-test the plugin** against itself:

   ```bash
   claude --plugin-dir .
   # then, in the session:
   /reload-plugins
   /claude-calibration:calibration-audit
   ```

## Tag and publish

```bash
git commit -am "chore(release): vX.Y.Z"
git tag vX.Y.Z          # MUST equal plugin.json version (the release workflow asserts this)
git push origin HEAD --tags
```

Pushing the `vX.Y.Z` tag triggers [`.github/workflows/release.yml`](../.github/workflows/release.yml),
which re-runs the gates, verifies the tag matches `plugin.json`, extracts the matching `CHANGELOG.md`
section, and creates the GitHub Release. There is no registry publish step.

## After release

Marketplace users pick up the new version with:

```text
/plugin update claude-calibration@odere-pro
```
