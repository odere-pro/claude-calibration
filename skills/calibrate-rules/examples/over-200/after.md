# Testing — TypeScript (split)

Split the original 250-line file into focused rule files under `.claude/rules/testing/`:

```
.claude/rules/testing/
├── unit.md           # ~80 lines, paths: ["**/*.{ts,tsx}"]
├── e2e.md            # ~80 lines, paths: ["e2e/**/*.{ts,tsx}", "playwright/**"]
└── coverage.md       # ~40 lines, paths: ["**/*.{ts,tsx}"]
```

Each file's frontmatter:

```yaml
---
name: testing-unit-typescript
description: Unit-test conventions for TypeScript code (Vitest).
paths:
  - "**/*.{ts,tsx}"
---
```

Why: Claude only pays the rule's context cost when a matching file is open; one focused rule per
topic is easier to maintain and easier to keep under 200 lines.
