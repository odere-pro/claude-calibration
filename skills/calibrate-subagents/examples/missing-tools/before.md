# Subagent missing tools allowlist (BEFORE)

`.claude/agents/code-reviewer.md`:

```yaml
---
name: code-reviewer
description: Reviews code.
---

You are a code reviewer. Look at the recent diff and call out issues.
```

## Why this is a problem

- **`tools:` is omitted** → the subagent inherits the **entire** tool catalogue from the main
  conversation, including all MCP tools. That's more tool schemas in its context (slower), and many
  more ways to go wrong (it could decide to make commits, run deploys, query a database, etc.).
- **`description: Reviews code.`** is too vague to route on — Claude won't know when to fire it
  vs. another reviewer.
- **`model:` omitted** → defaults to `inherit`, which usually means the orchestrating model (often
  Opus or Sonnet) — almost certainly more than a reviewer needs (Haiku is plenty for narrow review
  tasks).
- The body is also too thin (no instructions about what kinds of issues to flag, what *not* to flag,
  or what format to return).

Pattern signatures: `subagent:missing-tools`, `subagent:vague-description`, `subagent:default-inherit-model`.
