# After — explicit `version`

`.claude-plugin/plugin.json`:

```json
{
  "name": "my-plugin",
  "description": "A plugin that does useful things.",
  "version": "0.1.0",
  "author": {
    "name": "Jane Dev",
    "email": "jane@example.com"
  },
  "license": "MIT"
}
```

## What changed

- Added `"version": "0.1.0"` — semver, bumped on each release.

## A note on git distribution

When a plugin is distributed by git URL (the common case for early-stage plugins), **every
commit on the tracked branch is implicitly a new version** from Claude Code's perspective. The
manifest's `version` field is what users and marketplaces see; bumping it is a deliberate
release act, while the commit SHA is the precise pin.

Convention:

- Bump `version` whenever you'd want users to notice the change.
- Use a tag (`v0.1.0`) at the same commit so users can pin by tag rather than SHA.
- Don't worry about CalVer vs SemVer — pick one and be consistent.
