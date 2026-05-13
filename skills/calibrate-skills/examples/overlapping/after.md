# Calibrated: one canonical commit skill (AFTER)

`~/.claude/skills/commit/SKILL.md`:

```yaml
---
name: commit
description: >-
  Make a git commit. Generates a conventional-commits message from the staged diff and commits with
  it; with --review, asks before committing. Side-effecting; only you can invoke it (/commit).
argument-hint: "[--review]"
disable-model-invocation: true
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git commit:*)
---

# Commit

Generate a conventional-commits message from the staged diff, then commit. With `--review`, propose
the message and ask before committing.

## Do

1. `git status --short` — confirm there is staged content; abort with a clear message if not.
2. `git diff --staged` — read the staged content; draft a `<type>: <subject>` line + (optional) body
   following conventional commits.
3. If `--review` was passed: print the message + ask the user "commit? [y/N/edit]"; honour the reply.
   Otherwise: `git commit -m "<message>"`.
4. Print the resulting commit hash + the first line of the message.

## Hard rules

- Never amend an existing commit; never `--no-verify`.
- If the user's repo has its own commit-msg hook, let it run; don't bypass.
```

`~/.claude/skills/commit-helper/` — **deleted** (consolidated into `commit`).

## What changed

- Removed `commit-helper/` entirely.
- `commit/` now has the merged behaviour, gated with a `--review` flag for the "ask first" mode.
- Added `disable-model-invocation: true` (committing is side-effecting; Claude shouldn't auto-fire).
  Bonus: the description now costs **zero** standing context.
- Narrowed `allowed-tools` to git-only Bash subcommands.
- Description starts with the key use case, includes trigger keywords, well under 1,536 chars.
- Body is concrete and verifiable (specific commands, specific behaviours).

Verify: `scripts/lint.sh` reports zero `skill:overlap` and zero `skill:side-effecting-no-dmi` for
this skill.
