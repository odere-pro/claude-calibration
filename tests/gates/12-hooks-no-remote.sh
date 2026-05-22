#!/usr/bin/env bash
# G12 — hook scripts make no network calls (no curl/wget/remote npx). (CRITICAL)
# A hook fires on the hot path; fetching a remote payload there is the `hook:remote-untrusted`
# anti-pattern the plugin itself lints for.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
while IFS= read -r f; do
  if grep -nE '(\b(curl|wget)\b|npx[^\n]*https?://)' "$f" >/dev/null 2>&1; then
    echo "  FAIL: network call in hook script $f:"
    grep -nE '(\b(curl|wget)\b|npx[^\n]*https?://)' "$f" | sed 's/^/    /'
    fail=1
  fi
done < <(find hooks -type f -name '*.sh' | sort)

if [ "$fail" -ne 0 ]; then echo "G12 hooks-no-remote: FAIL"; exit 1; fi
echo "G12 hooks-no-remote: ok"
