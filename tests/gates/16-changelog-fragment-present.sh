#!/usr/bin/env bash
# G16 — every PR with a non-doc change adds a changelog/ fragment. (CRITICAL when comparable)
# Pass: the diff against the merge base is doc-only, OR it adds a changelog/<NN>-<slug>.md.
# Skip (exit 0): not a git work tree, on the base ref, or no base ref reachable (local/push runs).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

skip() { echo "G16 changelog-fragment: SKIP ($1)"; exit 0; }

command -v git >/dev/null 2>&1 || skip "git not on PATH"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || skip "not a git work tree"

# Resolve a comparison base, in order of preference.
base_ref=""
for candidate in "${GATE_BASE_REF:-}" "${GITHUB_BASE_REF:+origin/${GITHUB_BASE_REF}}" "origin/main" "main"; do
  [ -n "$candidate" ] || continue
  if git rev-parse --verify --quiet "$candidate" >/dev/null 2>&1; then base_ref="$candidate"; break; fi
done
[ -n "$base_ref" ] || skip "no base ref reachable (run: git fetch origin main)"

head_sha="$(git rev-parse HEAD)"
[ "$head_sha" != "$(git rev-parse "$base_ref")" ] || skip "HEAD is the base ref ($base_ref)"

merge_base="$(git merge-base "$base_ref" HEAD 2>/dev/null || true)"
[ -n "$merge_base" ] || skip "no merge base with $base_ref"

changed="$(git diff --name-only "${merge_base}...HEAD")"
[ -n "$changed" ] || skip "empty diff against $base_ref"

# Doc-only paths need no fragment.
is_doc_only() {
  case "$1" in
    changelog/*|docs/*|.github/*) return 0 ;;
    README.md|CHANGELOG.md|LICENSE|CODE_OF_CONDUCT.md|SECURITY.md|SUPPORT.md|CONTRIBUTING.md|CLAUDE.md|SOFTWARE-3-0.md) return 0 ;;
  esac
  return 1
}

non_doc=0; sample=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  is_doc_only "$p" && continue
  non_doc=$((non_doc + 1)); [ -n "$sample" ] || sample="$p"
done <<EOF
$changed
EOF

if [ "$non_doc" -eq 0 ]; then
  echo "G16 changelog-fragment: ok (diff is doc-only)"; exit 0
fi

# Non-doc change present — require a freshly added fragment.
added="$(git diff --name-only --diff-filter=A "${merge_base}...HEAD")"
while IFS= read -r p; do
  case "$p" in
    changelog/*.md) [ "$p" = "changelog/README.md" ] || { echo "G16 changelog-fragment: ok ($non_doc non-doc path(s), fragment added)"; exit 0; } ;;
  esac
done <<EOF
$added
EOF

echo "  FAIL: non-doc change present (e.g. $sample) but no changelog/<NN>-<slug>.md fragment was added"
echo "  see changelog/README.md"
echo "G16 changelog-fragment: FAIL"
exit 1
