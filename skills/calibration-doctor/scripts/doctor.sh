#!/usr/bin/env bash
# doctor.sh — fast structural health check for a Claude Code setup.
#
# Scope: "does it parse, does the referenced file exist, is the script executable" — not
# rubric-grade quality findings. Run /claude-calibration:calibration-audit for those.
#
# Output: TSV `<check>\t<status>\t<detail>` where status is one of:
#   ok       — passed
#   warn     — non-blocking concern (style, sanity threshold)
#   broken   — config likely doesn't work as intended (missing referenced file, invalid JSON,
#              required frontmatter field absent)
#
# Exit code is always 0. The SKILL.md interprets the TSV and presents the triage list.
#
# Usage: bash doctor.sh <project-dir>

set -u

PROJECT="${1:-$(pwd)}"
HOME_CLAUDE="${HOME}/.claude"

emit() {
  # check \t status \t detail
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
}

has_jq() { command -v jq >/dev/null 2>&1; }

# -----------------------------------------------------------------------------
# JSON files parse
# -----------------------------------------------------------------------------

for json_relpath in \
  ".claude-plugin/plugin.json" \
  ".claude/settings.json" \
  ".claude/settings.local.json" \
  ".mcp.json"; do
  abs="$PROJECT/$json_relpath"
  [ -f "$abs" ] || continue
  if has_jq; then
    if jq -e . "$abs" >/dev/null 2>&1; then
      emit "json:$json_relpath" "ok" "parses cleanly"
    else
      err="$(jq . "$abs" 2>&1 | head -1 | cut -c1-80)"
      emit "json:$json_relpath" "broken" "JSON parse error: ${err:-unknown}"
    fi
  else
    emit "json:$json_relpath" "warn" "jq not installed — skipped (install jq for parse check)"
  fi
done

# -----------------------------------------------------------------------------
# CLAUDE.md size sanity
# -----------------------------------------------------------------------------

if [ -f "$PROJECT/CLAUDE.md" ]; then
  lines=$(wc -l < "$PROJECT/CLAUDE.md" | tr -d ' ')
  if [ "$lines" -gt 800 ]; then
    emit "claude-md:size" "warn" "$lines lines (>800 — split or trim; see calibrate-claude-md)"
  elif [ "$lines" -gt 200 ]; then
    emit "claude-md:size" "warn" "$lines lines (over the 200-line heuristic)"
  else
    emit "claude-md:size" "ok" "$lines lines"
  fi
fi

# -----------------------------------------------------------------------------
# Hook scripts referenced in settings exist and are executable
# -----------------------------------------------------------------------------

check_hooks_file() {
  local settings_path="$1"
  [ -f "$settings_path" ] || return 0
  has_jq || return 0
  # Extract every `.hooks.*[].hooks[].command` and `.hooks.*[].command` value.
  local cmds
  cmds="$(jq -r '
    .hooks // {} |
    [.[] | (.[]? | .hooks[]?.command), (.[]?.command)] | .[] | select(. != null and . != "")
  ' "$settings_path" 2>/dev/null || true)"
  [ -z "$cmds" ] && return 0
  local seen_any=0
  while IFS= read -r raw; do
    [ -z "$raw" ] && continue
    seen_any=1
    # Expand ${CLAUDE_PLUGIN_ROOT} → the plugin root if we can guess one, else leave literal.
    # For settings.json under a project, CLAUDE_PLUGIN_ROOT isn't defined here; skip the
    # var-expansion check for that case (settings.json hooks usually reference repo paths).
    local cmd="$raw"
    # If the command starts with a shell command (sh -c, bash -c, etc.), pull out the first token
    # inside; otherwise take the first whitespace-separated token.
    local first_tok
    first_tok="$(printf '%s' "$cmd" | awk '{print $1}')"
    # Only check things that look like script paths (contain `/` and end in `.sh` or are absolute).
    case "$first_tok" in
      *.sh|/*|./*)
        # Resolve relative paths against project dir.
        local resolved
        case "$first_tok" in
          /*) resolved="$first_tok" ;;
          *) resolved="$PROJECT/$first_tok" ;;
        esac
        # Skip variable-prefixed paths we can't resolve.
        case "$resolved" in
          *'${'*|*'$('*) emit "hook:$(basename "$first_tok")" "ok" "uses variable — skipped existence check" ; continue ;;
        esac
        if [ ! -f "$resolved" ]; then
          emit "hook:$(basename "$first_tok")" "broken" "referenced script missing: $first_tok"
        elif [ ! -x "$resolved" ]; then
          emit "hook:$(basename "$first_tok")" "broken" "script not executable (chmod +x): $first_tok"
        else
          emit "hook:$(basename "$first_tok")" "ok" "exists + executable: $first_tok"
        fi
        ;;
      *)
        # Plain CLI like `pnpm prettier`, `npx eslint`, etc. — check binary on PATH.
        if command -v "$first_tok" >/dev/null 2>&1; then
          emit "hook:cli:$first_tok" "ok" "CLI on PATH"
        else
          emit "hook:cli:$first_tok" "warn" "CLI not on PATH (may be project-local): $first_tok"
        fi
        ;;
    esac
  done <<< "$cmds"
  if [ "$seen_any" -eq 0 ]; then
    emit "hooks:$(basename "$settings_path")" "ok" "no hook commands configured"
  fi
}

check_hooks_file "$PROJECT/.claude/settings.json"
check_hooks_file "$PROJECT/.claude/settings.local.json"

# -----------------------------------------------------------------------------
# Subagent frontmatter sanity — every agents/*.md must have name+description+tools
# -----------------------------------------------------------------------------

if [ -d "$PROJECT/.claude/agents" ]; then
  agents_dir="$PROJECT/.claude/agents"
elif [ -d "$PROJECT/agents" ] && [ -f "$PROJECT/.claude-plugin/plugin.json" ]; then
  agents_dir="$PROJECT/agents"
else
  agents_dir=""
fi
if [ -n "$agents_dir" ]; then
  for f in "$agents_dir"/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    fm_end_line=$(awk 'NR>1 && /^---[[:space:]]*$/{print NR; exit}' "$f" 2>/dev/null || echo 0)
    if [ "$fm_end_line" -le 1 ]; then
      emit "agent:$base" "broken" "no frontmatter block (must start with ---)"
      continue
    fi
    fm="$(awk -v n="$fm_end_line" 'NR<n' "$f" 2>/dev/null)"
    missing=""
    for required in name description; do
      if ! printf '%s' "$fm" | grep -qE "^${required}:" ; then
        missing="${missing:+$missing,}$required"
      fi
    done
    # tools: is required by the rubric; missing tools means agent inherits all (security smell)
    if ! printf '%s' "$fm" | grep -qE '^tools:'; then
      missing="${missing:+$missing,}tools"
    fi
    if [ -n "$missing" ]; then
      emit "agent:$base" "broken" "missing required frontmatter: $missing"
    else
      emit "agent:$base" "ok" "frontmatter complete"
    fi
  done
fi

# -----------------------------------------------------------------------------
# Skill frontmatter sanity — every skills/*/SKILL.md must have name+description
# -----------------------------------------------------------------------------

for skills_root in "$PROJECT/.claude/skills" "$PROJECT/skills"; do
  [ -d "$skills_root" ] || continue
  # The plugin root /skills/ only matters when this is a plugin.
  if [ "$skills_root" = "$PROJECT/skills" ] && [ ! -f "$PROJECT/.claude-plugin/plugin.json" ]; then
    continue
  fi
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    base="$(basename "$(dirname "$f")")"
    fm_end_line=$(awk 'NR>1 && /^---[[:space:]]*$/{print NR; exit}' "$f" 2>/dev/null || echo 0)
    if [ "$fm_end_line" -le 1 ]; then
      emit "skill:$base" "broken" "no frontmatter block (must start with ---)"
      continue
    fi
    fm="$(awk -v n="$fm_end_line" 'NR<n' "$f" 2>/dev/null)"
    missing=""
    for required in name description; do
      if ! printf '%s' "$fm" | grep -qE "^${required}:" ; then
        missing="${missing:+$missing,}$required"
      fi
    done
    if [ -n "$missing" ]; then
      emit "skill:$base" "broken" "missing required frontmatter: $missing"
    else
      emit "skill:$base" "ok" "frontmatter complete"
    fi
  done < <(find "$skills_root" -type f -name SKILL.md 2>/dev/null)
done

# -----------------------------------------------------------------------------
# .mcp.json server commands resolvable
# -----------------------------------------------------------------------------

if [ -f "$PROJECT/.mcp.json" ] && has_jq; then
  servers="$(jq -r '.mcpServers // {} | to_entries[] | "\(.key)\t\(.value.command // "")"' "$PROJECT/.mcp.json" 2>/dev/null || true)"
  if [ -n "$servers" ]; then
    while IFS=$'\t' read -r name cmd; do
      [ -z "$name" ] && continue
      if [ -z "$cmd" ]; then
        emit "mcp:$name" "warn" "no command field"
        continue
      fi
      if command -v "$cmd" >/dev/null 2>&1; then
        emit "mcp:$name" "ok" "command on PATH: $cmd"
      else
        # npx/uvx are special — they fetch on demand, so a missing local binary is fine
        case "$cmd" in
          npx|uvx|pnpm|yarn) emit "mcp:$name" "ok" "uses package runner: $cmd" ;;
          *) emit "mcp:$name" "warn" "command not on PATH: $cmd (server may not start)" ;;
        esac
      fi
    done <<< "$servers"
  fi
fi

# -----------------------------------------------------------------------------
# .gitignore covers .claude/calibration/
# -----------------------------------------------------------------------------

if [ -f "$PROJECT/.gitignore" ]; then
  if grep -qE '(^|/)\.claude/calibration(/|$)|^\.claude/calibration' "$PROJECT/.gitignore"; then
    emit "gitignore:calibration" "ok" ".claude/calibration/ is ignored"
  else
    # Only warn if calibration runs actually exist in this repo
    if [ -d "$PROJECT/.claude/calibration" ]; then
      emit "gitignore:calibration" "warn" ".claude/calibration/ exists but is not in .gitignore (run artifacts will be tracked)"
    fi
  fi
fi

# -----------------------------------------------------------------------------
# Done — the SKILL.md formats and prints the summary
# -----------------------------------------------------------------------------

exit 0
