#!/usr/bin/env bash
# G15 — markdown style lint. (ADVISORY — warns, never fails the suite)
# Uses markdownlint-cli via npx when available; otherwise degrades to a notice.
set -uo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)" || exit 0

if ! command -v npx >/dev/null 2>&1; then
  echo "G15 markdown-lint: SKIP (npx not available) [advisory]"
  exit 0
fi

# --no-install avoids surprise downloads in CI/local; only lints if the tool is present.
if npx --no-install markdownlint-cli --version >/dev/null 2>&1; then
  if npx --no-install markdownlint-cli "**/*.md" "#node_modules" 2>&1; then
    echo "G15 markdown-lint: ok"
  else
    echo "G15 markdown-lint: warnings above [advisory — not failing]"
  fi
else
  echo "G15 markdown-lint: SKIP (markdownlint-cli not installed) [advisory]"
fi
exit 0
