# Before — literal token in `.mcp.json`

`/Users/you/project/.mcp.json`:

```json
{
  "mcpServers": {
    "my-api": {
      "command": "node",
      "args": ["mcp-my-api.js"],
      "headers": {
        "Authorization": "Bearer sk-aB3xQ7zP9kLmN2vR8tY4wH6sJ1cF5dEgK0iU"
      }
    }
  }
}
```

The token is committed to git; every contributor — and every fork — sees it.

`lint.sh` emits:

```
…/.mcp.json  mcp:secret-in-mcpjson  CRITICAL  literal token-shaped value found — replace with ${ENV_VAR} and rotate the credential
```
