#!/usr/bin/env bash
# G11 — CHANGELOG.md has a section for the current plugin.json version. (CRITICAL)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

ver="$(jq -r '.version // empty' .claude-plugin/plugin.json)"
if [ -z "$ver" ]; then
  echo "  FAIL: plugin.json has no version"; echo "G11 changelog-version: FAIL"; exit 1
fi

if grep -qE "^##[[:space:]]+\[${ver}\]" CHANGELOG.md; then
  echo "G11 changelog-version: ok (v${ver})"
else
  echo "  FAIL: CHANGELOG.md has no '## [${ver}]' section"
  echo "G11 changelog-version: FAIL"
  exit 1
fi
