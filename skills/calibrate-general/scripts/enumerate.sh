#!/usr/bin/env bash
# enumerate.sh — emit a single synthesizer row for the project.
# Usage: enumerate.sh [project-dir]
# Output: scope\tpath  (always: general\t<PROJECT_DIR>)
set -euo pipefail
PROJECT="${1:-$(pwd)}"
emit() { printf '%s\t%s\n' "$1" "$2"; }
emit general "$PROJECT"
