#!/usr/bin/env bash
# G9 — no machine-absolute home paths (/Users/<name>, /home/<name>) in shipped files. (CRITICAL)
# These leak an author's machine layout and break on every other machine.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

# Component dirs + root docs that actually ship and are read at runtime/by users.
# `examples/` is excluded on purpose: before/after fixtures deliberately embody anti-patterns
# (e.g. a placeholder `/Users/you/project` path) to teach the lint that flags them.
targets=(skills agents rules hooks docs .claude-plugin README.md SOFTWARE-3-0.md)

hits="$(grep -rnE '/(Users|home)/[A-Za-z0-9._-]+' "${targets[@]}" 2>/dev/null | grep -v '/examples/' || true)"
if [ -n "$hits" ]; then
  echo "  FAIL: absolute home path(s) found:"
  printf '%s\n' "$hits" | sed 's/^/    /'
  echo "G9 no-absolute-paths: FAIL"
  exit 1
fi
echo "G9 no-absolute-paths: ok"
