#!/usr/bin/env bash
# plugin-filter.sh — shared allow-list / block-list filter for plugin enumeration.
#
# Sourced (never executed) by the cache-touching enumerate.sh scripts:
#   calibrate-plugins, calibrate-skills, calibrate-subagents.
#
# Transport: the CALIBRATION_PLUGIN_FILTER env var. Canonical spec (pipe-joined
# directives; empty/unset => no filtering, audit everything — the backward-compatible
# default):
#
#   include:foo,bar          allow-list — only these plugin names are audited
#   exclude:baz              block-list — every plugin except these
#   scope:global|local|all   whole-scope restriction (default all)
#   e.g.  "include:foo,bar|scope:global"
#
# Exactly one of include:/exclude: (or neither). scope: is orthogonal:
#   global = anything under ~/.claude/plugins/cache/ (installed/marketplaces rows too)
#   local  = plugin-self / project rows
#
# Bash 3.2 compatible (macOS) — no mapfile/readarray. Safe to source under
# `set -euo pipefail`: the predicates return non-zero by design, so call them only
# in a conditional (`if ! cpf_in_scope …; then continue; fi`), never bare.

# cpf_extract_plugin_name <path> — echo the <plugin> component of a cache path
# (~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/...). Handles both a bare
# version dir (calibrate-plugins) and a nested file (…/skills/x/SKILL.md); falls back
# to basename for any path not under a cache/ dir.
cpf_extract_plugin_name() {
  local path="$1" rest
  case "$path" in
    */cache/*/*)
      rest="${path##*/cache/}"   # <marketplace>/<plugin>/<version>/...
      rest="${rest#*/}"          # <plugin>/<version>/...   (strip marketplace)
      printf '%s' "${rest%%/*}"  # <plugin>
      ;;
    *)
      printf '%s' "${path##*/}"  # basename fallback
      ;;
  esac
}

# _cpf_csv_has <needle> <comma-list> — 0 if needle is an exact element of the list.
_cpf_csv_has() {
  local needle="$1" list="$2" item
  local IFS=,
  # shellcheck disable=SC2086  # intentional word-splitting on the comma list
  for item in $list; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

# _cpf_want_scope — echo the scope directive (global|local|all) from the spec.
_cpf_want_scope() {
  local spec="${CALIBRATION_PLUGIN_FILTER:-}" directive want="all"
  local IFS='|'
  # shellcheck disable=SC2086  # intentional word-splitting on the pipe-joined spec
  for directive in $spec; do
    case "$directive" in scope:*) want="${directive#scope:}" ;; esac
  done
  printf '%s' "$want"
}

# cpf_scope_allowed <install_scope> — 0 if the scope directive permits this install
# scope. Ignores name allow/block; use for non-plugin-specific rows (the installed /
# marketplaces state files).
cpf_scope_allowed() {
  local iscope="$1"
  [ -n "${CALIBRATION_PLUGIN_FILTER:-}" ] || return 0
  case "$(_cpf_want_scope)" in
    global) [ "$iscope" = "global" ] || return 1 ;;
    local)  [ "$iscope" = "local" ]  || return 1 ;;
  esac
  return 0
}

# cpf_in_scope <plugin_name> <install_scope> — 0 = audit, 1 = skip. install_scope is
# global|local. Empty CALIBRATION_PLUGIN_FILTER => always 0 (audit everything).
cpf_in_scope() {
  local name="$1" iscope="$2" spec="${CALIBRATION_PLUGIN_FILTER:-}"
  [ -n "$spec" ] || return 0

  cpf_scope_allowed "$iscope" || return 1

  local directive inc="" exc=""
  local IFS='|'
  # shellcheck disable=SC2086  # intentional word-splitting on the pipe-joined spec
  for directive in $spec; do
    case "$directive" in
      include:*) inc="${directive#include:}" ;;
      exclude:*) exc="${directive#exclude:}" ;;
    esac
  done

  if [ -n "$inc" ]; then
    _cpf_csv_has "$name" "$inc" || return 1
  fi
  if [ -n "$exc" ]; then
    _cpf_csv_has "$name" "$exc" && return 1
  fi
  return 0
}
