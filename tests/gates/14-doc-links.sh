#!/usr/bin/env bash
# G14 — no dangling relative *.md links across the shipped docs. (CRITICAL)
# Resolves each `](target.md)` link relative to its file and checks the target exists.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
while IFS= read -r f; do
  dir="$(dirname -- "$f")"
  # extract markdown link targets: the (...) part of ](...)
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    target="${target%% *}"      # drop optional `"title"` after a space
    target="${target%%#*}"      # drop #anchor
    case "$target" in
      ""|http://*|https://*|mailto:*|\#*) continue ;;
      *://*) continue ;;
    esac
    case "$target" in *.md) ;; *) continue ;; esac   # only intra-doc .md links
    if [ ! -e "$dir/$target" ]; then
      echo "  FAIL: $f -> $target (target missing)"
      fail=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
done < <( { find docs rules -type f -name '*.md'; find . -maxdepth 1 -type f -name '*.md'; } | sort -u)

if [ "$fail" -ne 0 ]; then echo "G14 doc-links: FAIL"; exit 1; fi
echo "G14 doc-links: ok"
