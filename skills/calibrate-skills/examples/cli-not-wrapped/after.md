---
name: open-pr
description: >-
  Opens a pull request for the current branch via the `gh` CLI. Use when the user asks to open,
  raise, or create a PR after committing changes. Loaded on demand
  (`disable-model-invocation: true`); never auto-fires.
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Bash(gh *), Bash(git status), Bash(git log:*)
---

# Open a pull request

## When to use

- The user says "open a PR" / "raise a PR" / "create a PR" after a commit lands.
- The current branch has at least one commit ahead of `origin/main`.

Do NOT use this skill for force-push, branch deletion, or repo creation — those each have their
own skill.

## Workflow

1. `git status` to verify the working tree is clean.
2. `git log origin/main..HEAD --oneline` to surface the commit list for the PR body.
3. `gh pr create --fill` to open the PR with the commit message body.
4. Print the resulting PR URL.

## Limits

- `allowed-tools` is scoped to `Bash(gh *)`, `Bash(git status)`, `Bash(git log:*)` — this skill
  cannot run other commands.
- `disable-model-invocation: true` is REQUIRED. Opening a PR is a side-effecting action; Claude
  must never auto-fire it.
- Does not handle merge conflicts; the user must rebase manually first.

<!--
After-state verify (calibrate-skills/lint.sh):
- skill:vague-description ✓ (routing words "use when", "after" present; description > 80 chars)
- skill:allowed-tools-broad ✓ (no bare Bash/Edit/Write)
- skill:cli-not-wrapped ✓ (Bash(gh *) scope declared)
- skill:side-effecting-no-dmi ✓ (disable-model-invocation: true present)
-->
