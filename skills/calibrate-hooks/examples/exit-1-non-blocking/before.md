# Before — `exit 1` for what should be enforcement

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
  exit 1
fi

exit 0
```

## Why this is wrong

Claude treats `exit 1` as a **non-blocking warning** — the user sees the message in the terminal,
but the `Write` tool call still goes through. The `[Hook] BLOCKED: …` message is a lie.

Signature: `hook:exit-1-non-blocking` (HIGH).
