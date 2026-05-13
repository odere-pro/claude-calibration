---
name: open-pr
description: Open a pull request for the current branch.
allowed-tools: Read, Bash, Edit
---

# Open a pull request

## Workflow

1. Run `git status` to verify the working tree is clean.
2. Run `gh pr create --fill` to open the PR with the commit message body.
3. Print the resulting PR URL.

## Notes

- This skill assumes `gh` is authenticated.
- It does not handle merge conflicts.

<!--
Findings on this file (from calibrate-skills/lint.sh):
- skill:vague-description MEDIUM — description < 80 chars and lacks routing words.
- skill:allowed-tools-broad LOW — bare `Bash`, `Edit`.
- skill:cli-not-wrapped LOW — body invokes `gh` but allowed-tools has no `Bash(gh *)` scope.
- skill:side-effecting-no-dmi HIGH — body uses "push"/"open"/"create"-style side effects
  (`gh pr create`) but no `disable-model-invocation: true`. Claude can auto-fire this.
-->
