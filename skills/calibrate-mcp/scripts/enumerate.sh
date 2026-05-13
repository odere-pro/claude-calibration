#!/usr/bin/env bash
# enumerate.sh — list every MCP-bearing config layer.
# Usage: enumerate.sh [project-dir]
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

[ -f "$PROJECT/.mcp.json" ] && emit project "$PROJECT/.mcp.json"
if [ -f "$HOME/.claude.json" ] && grep -q '"mcpServers"' "$HOME/.claude.json"; then
  emit user-claude-json "$HOME/.claude.json"
fi
case "$(uname -s)" in
  Darwin) [ -f "/Library/Application Support/ClaudeCode/managed-mcp.json" ] && emit managed "/Library/Application Support/ClaudeCode/managed-mcp.json" ;;
  Linux)  [ -f "/etc/claude-code/managed-mcp.json" ] && emit managed "/etc/claude-code/managed-mcp.json" ;;
esac

# subagent-scoped MCP (in mcpServers frontmatter)
for d in "$PROJECT/.claude/agents" "$HOME/.claude/agents"; do
  [ -d "$d" ] || continue
  find "$d" -maxdepth 1 -name '*.md' -print 2>/dev/null \
    | while read -r f; do
        if awk 'BEGIN{state=0} /^---$/{state++; next} state==1 && /^mcpServers:/{found=1} END{exit !found}' "$f"; then
          if [[ "$d" == "$HOME"* ]]; then emit subagent-user "$f"; else emit subagent-project "$f"; fi
        fi
      done
done
