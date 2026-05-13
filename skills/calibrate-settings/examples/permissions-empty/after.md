# After — baseline allow-list

`/Users/you/project/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(git diff:*)",
      "Bash(git status:*)",
      "Bash(git log:*)",
      "Bash(ls:*)",
      "Bash(find:*)",
      "Bash(grep:*)"
    ]
  },
  "env": {}
}
```

Narrow, read-only entries only — no `Bash(*)`, no `Bash(rm *)`, no `Bash(sudo *)`. Add
project-specific tools (e.g. `Bash(pnpm test:*)`) as needed, one narrow pattern at a time.

`lint.sh` no longer emits `settings:permissions-empty`.
