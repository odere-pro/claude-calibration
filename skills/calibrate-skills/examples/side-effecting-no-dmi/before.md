# Side-effecting skill missing disable-model-invocation (BEFORE)

`.claude/skills/deploy/SKILL.md`:

```yaml
---
name: deploy
description: Deploy the app to staging.
---

Run `pnpm deploy:staging`, then run smoke tests, then ping #deployments.
```

## Why this is a problem

`description: Deploy the app to staging` matches a lot of phrases Claude might decide are about
deploying. Without `disable-model-invocation: true`, **Claude can autonomously fire this skill** —
i.e., deploy to staging because the conversation drifted near "ship it." That's an unacceptable
side-effect for any deploy / commit / post / destructive workflow.

The description is also in context every request (small, but at the principle level it's pure tax —
side-effecting skills should cost zero context until you invoke them).

`allowed-tools` is implicit (everything Claude can normally use) — there's no scoping to the actual
commands the deploy needs.

Pattern signatures emitted: `skill:side-effecting-no-dmi`, `skill:allowed-tools-broad`,
`skill:vague-description` (the description is too generic for routing).
