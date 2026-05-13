#!/usr/bin/env bash
# enumerate.sh — list every settings.json layer.
# Usage: enumerate.sh [project-dir]
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }

[ -f "$HOME/.claude/settings.json" ]        && emit user "$HOME/.claude/settings.json"
[ -f "$HOME/.claude/settings.local.json" ]  && emit user-local "$HOME/.claude/settings.local.json"
[ -f "$PROJECT/.claude/settings.json" ]     && emit project "$PROJECT/.claude/settings.json"
[ -f "$PROJECT/.claude/settings.local.json" ] && emit project-local "$PROJECT/.claude/settings.local.json"
case "$(uname -s)" in
  Darwin) [ -f "/Library/Application Support/ClaudeCode/managed-settings.json" ] && emit managed "/Library/Application Support/ClaudeCode/managed-settings.json" ;;
  Linux)  [ -f "/etc/claude-code/managed-settings.json" ] && emit managed "/etc/claude-code/managed-settings.json" ;;
esac
[ -f "$HOME/.claude.json" ] && emit user-claude-json "$HOME/.claude.json"
