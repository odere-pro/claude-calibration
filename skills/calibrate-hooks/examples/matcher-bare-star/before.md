# Before — bare `"*"` matcher on a hot event

`.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/lint-on-edit.sh",
            "description": "Lint edited files"
          }
        ]
      }
    ]
  }
}
```

## Why this is wrong

`PreToolUse` is a **hot event** — it fires on every tool call. With `matcher: "*"`, the lint
script runs on `Read`, `Grep`, `Bash`, `WebFetch`, and every MCP tool. That's a) cycles spent
running a linter that has nothing to lint and b) a real risk of slowing down every step Claude
takes.

Signature: `hook:matcher-bare-star` (MEDIUM).
