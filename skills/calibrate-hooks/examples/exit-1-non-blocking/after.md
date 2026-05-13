# After — `exit 2` to actually block

`.claude/hooks/block-large-writes.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""')
LINES=$(echo "$CONTENT" | wc -l)

if [ "$LINES" -gt 800 ]; then
  echo "[Hook] BLOCKED: file exceeds 800 lines ($LINES lines)" >&2
  echo "[Hook] Split into smaller modules" >&2
  exit 2
fi

exit 0
```

## Hook exit semantics

| Exit code | Meaning |
|---|---|
| `0` | Pass — tool call proceeds, hook output is silent. |
| `1` | Non-blocking warning — message surfaces to the user, tool call still proceeds. |
| `2` | **Block** — tool call is denied, stderr is surfaced back to Claude so it can revise. |

Use `exit 2` whenever the hook's message says "BLOCKED", "denied", or otherwise implies the
action was prevented. Use `exit 1` only when the intent is genuinely "warn, don't block".
