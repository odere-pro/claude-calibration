# Before — manifest without `version`

`.claude-plugin/plugin.json`:

```json
{
  "name": "my-plugin",
  "description": "A plugin that does useful things.",
  "author": {
    "name": "Jane Dev",
    "email": "jane@example.com"
  },
  "license": "MIT"
}
```

## Why this is wrong (-ish)

The manifest works — `name` is the only strictly required field — but without `version`:

- Users can't pin a specific release.
- Marketplaces can't deduplicate or display "what version am I running?".
- On **git distribution every commit becomes a new implicit version** — so the same plugin
  state shows as "different" between clones, but there's no human-readable version to refer
  to.

Signature: `plugin:missing-version` (LOW).
