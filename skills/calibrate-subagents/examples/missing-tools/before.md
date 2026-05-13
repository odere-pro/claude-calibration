---
name: pr-reviewer
description: Reviews open PRs.
---

# PR reviewer

You review the diff of the current branch against `main` and report issues by severity. Focus on
security, correctness, and code-style fit.

## Workflow

1. Diff the branch against `main`.
2. Identify findings.
3. Group by severity (CRITICAL / HIGH / MEDIUM / LOW).
4. Return the structured list.

<!--
Findings on this file (from calibrate-subagents/lint.sh):
- subagent:missing-tools HIGH — no `tools:` line. This agent inherits EVERY tool in scope,
  including every MCP server attached to the parent context. The single biggest subagent footgun.
- subagent:default-inherit-model MEDIUM — no `model:` line. Defaults to `inherit`, so a parent
  on Opus silently runs this agent on Opus too.
- subagent:vague-description MEDIUM — description is 20 chars, no routing words.
-->
