# Before — empty permissions.allow

`/Users/you/project/.claude/settings.json`:

```json
{
  "env": {}
}
```

There is no `permissions.allow` block. Every Bash invocation (`git status`, `ls`, `find`) prompts
for manual approval — the experience degrades for every contributor on this project.

`lint.sh` emits:

```
…/.claude/settings.json  settings:permissions-empty  LOW  no permissions.allow entries — every tool call prompts for manual approval
```
