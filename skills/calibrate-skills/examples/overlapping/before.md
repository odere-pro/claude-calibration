# Two overlapping skills (BEFORE)

`~/.claude/skills/commit/SKILL.md`:

```yaml
---
name: commit
description: Make a git commit with a good message.
---

Generate a conventional commit message based on the staged changes and run `git commit`.
```

`~/.claude/skills/commit-helper/SKILL.md`:

```yaml
---
name: commit-helper
description: Help write good commit messages.
---

Look at the staged diff and propose a commit message; ask before committing.
```

## Why this is a problem

Both descriptions match phrases like "I want to commit", "make a commit", "write a commit message".
Claude's router has to pick one and picks **inconsistently** — sometimes the wrong skill fires. Both
skills' descriptions are in context every request. The Claude Code docs call this out as a Must
violation: *"One skill = one capability. Overlapping skills compete for routing — split or merge,
don't duplicate."*

Also missing: neither skill has `disable-model-invocation: true`. Committing is side-effecting; Claude
should not auto-fire either of them just because the conversation drifted toward "ship it."

Pattern signatures emitted: `skill:overlap`, `skill:side-effecting-no-dmi` (×2).
