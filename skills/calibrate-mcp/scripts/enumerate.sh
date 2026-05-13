#!/usr/bin/env bash
# enumerate.sh — list every MCP configuration source across user + project + agents.
# Usage: enumerate.sh [project-dir]
# Output: scope\tpath  (scopes: project, user, agent)
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

# Project-level .mcp.json
[ -f "$PROJECT/.mcp.json" ] && emit project "$PROJECT/.mcp.json"

# User-level: ~/.claude.json holds mcpServers as a nested block; emit the file path best-effort.
# The lint step does the actual extraction.
[ -f "$HOME/.claude.json" ] && emit user "$HOME/.claude.json"

# Agent files declaring mcpServers in frontmatter — user scope
if [ -d "$HOME/.claude/agents" ]; then
  grep -l '^mcpServers:' "$HOME/.claude/agents"/*.md 2>/dev/null \
    | while read -r f; do emit agent "$f"; done
fi

# Agent files declaring mcpServers in frontmatter — project scope
if [ -d "$PROJECT/.claude/agents" ]; then
  grep -l '^mcpServers:' "$PROJECT/.claude/agents"/*.md 2>/dev/null \
    | while read -r f; do emit agent "$f"; done
fi
