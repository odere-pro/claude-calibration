# Calibrated (AFTER)

`.claude/skills/deploy/SKILL.md`:

```yaml
---
name: deploy
description: >-
  Deploy the app to staging — runs `pnpm deploy:staging`, smoke tests, and pings #deployments.
  Side-effecting; only you can invoke it (/deploy).
argument-hint: "[--skip-smoke]"
disable-model-invocation: true
allowed-tools: Bash(pnpm deploy:staging*), Bash(pnpm test:smoke*), Bash(curl -X POST https://hooks.slack.com/*)
---

# Deploy

Deploy the app to the staging environment. Runs the build, smoke tests, and a Slack notification.

## Do

1. `pnpm deploy:staging` — print the deploy URL on success; on failure, print the last 50 lines of
   stderr and stop.
2. Unless `--skip-smoke`: `pnpm test:smoke` against the new URL; on failure, print the failing test
   names and stop (do **not** roll back automatically — that's a separate command).
3. Post a one-line success message to #deployments via the configured Slack webhook
   (`$STAGING_DEPLOY_WEBHOOK`).

## Hard rules

- Never deploy if the working tree is dirty (run `git status --short` first; abort if non-empty).
- Never deploy from a non-default branch unless `--branch <name>` is in the arguments.
- The Slack post is best-effort; if it fails, the deploy still counts as successful.
```

## What changed

- Added `disable-model-invocation: true` → Claude can no longer auto-fire; the description drops to
  zero context cost; the skill is only invokable as `/deploy`.
- Description now states the steps, the side-effect, and the invocation form. Well under 1,536 chars.
- Narrowed `allowed-tools` to the precise commands the deploy needs (no bare `Bash`).
- Body is concrete: every step has a specific command and a specific failure mode.

Verify: `scripts/lint.sh` reports zero `skill:side-effecting-no-dmi`, zero `skill:allowed-tools-broad`,
zero `skill:vague-description` for this skill.
