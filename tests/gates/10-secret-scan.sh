#!/usr/bin/env bash
# G10 — no concrete secret-shaped tokens in shipped files. (CRITICAL)
# Targets real credential formats (not the pattern *descriptions* the plugin's own rubric carries),
# so it dogfoods `claude-md:secret-leak` without false-positiving on signatures.md / lint.sh.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

targets=(skills agents rules hooks docs .claude-plugin README.md SOFTWARE-3-0.md CHANGELOG.md)

# Concrete token formats: OpenAI, GitHub PAT (classic + fine-grained), AWS, Slack, private keys.
secret_re='(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{12,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

# `examples/` is excluded on purpose: the `secret-in-mcpjson` before.md fixture carries a *fake*
# token to demonstrate the `mcp:secret-in-mcpjson` leak the plugin detects.
hits="$(grep -rnE "$secret_re" "${targets[@]}" 2>/dev/null | grep -v '/examples/' || true)"
if [ -n "$hits" ]; then
  echo "  FAIL: possible secret(s) found:"
  printf '%s\n' "$hits" | sed 's/^/    /'
  echo "G10 secret-scan: FAIL"
  exit 1
fi
echo "G10 secret-scan: ok"
