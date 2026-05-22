#!/usr/bin/env bash
# G8 — shellcheck every shipped/CI shell script at error severity. (CRITICAL)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "G8 shellcheck: SKIP (shellcheck not installed)"
  exit 0
fi

# `-exec ... {} +` batches all matches into one invocation and runs nothing if none are found.
# Portable across BSD (macOS) and GNU find — avoids bash 4's `mapfile`.
if find hooks skills tests scripts .claude/hooks -type f -name '*.sh' -exec shellcheck -S error -x {} +; then
  echo "G8 shellcheck: ok"
else
  echo "G8 shellcheck: FAIL"
  exit 1
fi
