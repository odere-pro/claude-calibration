# After — narrowed matcher

`.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "if": { "file_path": "**/*.{ts,tsx,js,jsx}" },
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/lint-on-edit.sh",
            "description": "Lint edited JS/TS files"
          }
        ]
      }
    ]
  }
}
```

## What changed

- `matcher` lists only the tools that actually write files (`Edit|Write|MultiEdit`).
- An `if` field scopes the hook further to the file globs the lint script knows how to handle.
- Reads, greps, bashes, and MCP calls no longer trigger the lint script — it now runs only when
  there's something to lint.

When the hot event genuinely needs to see every tool call (e.g. a security audit hook), keep
the bare `*` but make the hook script's first action a fast early-exit on the tool name.
