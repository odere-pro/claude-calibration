#!/usr/bin/env bash
# Shared helpers for the calibration gate suite.
# Sourced by each gate; never executed directly.

# Absolute repo root, derived from this file's location.
gates_repo_root() {
  CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd
}

# Print the YAML frontmatter (between the first two `---` fences) of file $1.
gates_frontmatter() {
  awk 'BEGIN{s=0}
       /^---[[:space:]]*$/{s++; if(s==2) exit; next}
       s==1{print}' "$1"
}

# The nine canonical per-feature bundles (the calibrate-* contract).
# Consumed by gates that source this file (e.g. 07-signature-dispatch-integrity.sh).
# shellcheck disable=SC2034
GATES_FEATURES="claude-md rules settings skills subagents hooks mcp plugins general"

# The known signature prefixes (used to extract <prefix>:<name> tokens safely).
# shellcheck disable=SC2034
GATES_SIG_PREFIXES="claude-md|rule|settings|skill|subagent|hook|mcp|plugin|general"
