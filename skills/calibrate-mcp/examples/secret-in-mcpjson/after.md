# After — `${ENV_VAR}` substitution

`/Users/you/project/.mcp.json`:

```json
{
  "mcpServers": {
    "my-api": {
      "command": "node",
      "args": ["mcp-my-api.js"],
      "env": {
        "MY_API_KEY": "${MY_API_KEY}"
      },
      "headers": {
        "Authorization": "Bearer ${MY_API_KEY}"
      }
    }
  }
}
```

The placeholder substitutes from the environment at session start. The original token has been
**rotated** (the old one was committed; treat it as exposed). Set `MY_API_KEY` in your shell or in
`~/.claude/settings.local.json`'s `env` block.

`lint.sh` no longer emits `mcp:secret-in-mcpjson`.
