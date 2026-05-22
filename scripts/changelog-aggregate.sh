#!/usr/bin/env bash
# scripts/changelog-aggregate.sh
# Promote fragments under `changelog/` into `CHANGELOG.md`'s `[Unreleased]`
# block, leading each bullet with the short SHA of the commit that
# introduced the fragment. Idempotent against an empty fragment dir.
#
# Usage:
#   bash scripts/changelog-aggregate.sh            # dry-run; print to stdout
#   bash scripts/changelog-aggregate.sh --apply    # rewrite CHANGELOG.md and
#                                                  # remove the fragments
#
# Hard rules:
# - Fragment filenames are anything matching `changelog/*.md` except
#   `README.md`. Each fragment's first non-empty, non-comment line is the bullet.
# - SHA resolution per fragment:
#     1. A leading `<!-- sha: <sha> -->` hint wins (for historic backfills).
#     2. Otherwise resolved via `git log -1 --format=%H -- <fragment>`.
#     3. If neither yields a SHA (uncommitted), the bullet shows `unreleased`.
# - Fragments are sorted by introducing commit date (oldest first); uncommitted
#   fragments are appended last in lexical order.
# - The aggregator inserts under the first `### Added` inside `## [Unreleased]`.
#   If that heading is missing, the script exits 1.

set -Eeuo pipefail

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${THIS_DIR}/.." && pwd)"
FRAGMENTS_DIR="${REPO_ROOT}/changelog"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"

APPLY=0
case "${1:-}" in
  --apply) APPLY=1 ;;
  ""|--dry-run) APPLY=0 ;;
  -h|--help)
    sed -n '2,20p' "$0"
    exit 0
    ;;
  *)
    printf 'changelog-aggregate: unknown option: %s\n' "$1" >&2
    exit 1
    ;;
esac

if [ ! -d "${FRAGMENTS_DIR}" ]; then
  printf 'changelog-aggregate: %s does not exist\n' "${FRAGMENTS_DIR}" >&2
  exit 1
fi
if [ ! -f "${CHANGELOG}" ]; then
  printf 'changelog-aggregate: %s does not exist\n' "${CHANGELOG}" >&2
  exit 1
fi

# Collect fragments, skipping README.md. Plain string list keeps Bash 3.2 happy.
fragments=""
for f in "${FRAGMENTS_DIR}"/*.md; do
  if [ ! -f "${f}" ]; then
    continue
  fi
  base="$(basename "${f}")"
  case "${base}" in
    README.md) continue ;;
  esac
  fragments="${fragments}
${f}"
done
fragments="$(printf '%s' "${fragments}" | sed '/^$/d')"

if [ -z "${fragments}" ]; then
  printf 'changelog-aggregate: no fragments under %s\n' "${FRAGMENTS_DIR}" >&2
  exit 0
fi

# Build "<sortkey>\t<sha>\t<file>" rows, then sort.
rows=""
while IFS= read -r f; do
  if [ -z "${f}" ]; then
    continue
  fi
  hint_line="$(head -n 1 "${f}" 2>/dev/null || true)"
  case "${hint_line}" in
    "<!-- sha:"*"-->"|"<!-- SHA:"*"-->")
      hint_sha="$(printf '%s' "${hint_line}" \
        | sed -E 's/^[[:space:]]*<!--[[:space:]]*[Ss][Hh][Aa]:[[:space:]]*([0-9a-fA-F]+)[[:space:]]*-->[[:space:]]*$/\1/')"
      ;;
    *)
      hint_sha=""
      ;;
  esac
  if [ -n "${hint_sha}" ]; then
    sha="${hint_sha}"
    ts="$(git -C "${REPO_ROOT}" log -1 --format=%ct "${sha}" 2>/dev/null || true)"
    if [ -z "${ts}" ]; then
      ts="9999999998"
    fi
  else
    ts="$(git -C "${REPO_ROOT}" log -1 --format=%ct -- "${f}" 2>/dev/null || true)"
    sha="$(git -C "${REPO_ROOT}" log -1 --format=%h -- "${f}" 2>/dev/null || true)"
    if [ -z "${sha}" ]; then
      ts="9999999999"
      sha="unreleased"
    fi
  fi
  rows="${rows}
${ts}	${sha}	${f}"
done <<EOF
${fragments}
EOF
rows="$(printf '%s' "${rows}" | sed '/^$/d' | LC_ALL=C sort)"

# Render bullets.
bullets=""
while IFS=$'\t' read -r _ts sha f; do
  if [ -z "${f}" ]; then
    continue
  fi
  body="$(sed -e 's/^[[:space:]]\{1,\}//' -e 's/[[:space:]]\{1,\}$//' "${f}" \
    | sed -E '/^[[:space:]]*<!--[[:space:]]*[Ss][Hh][Aa]:[[:space:]]*[0-9a-fA-F]+[[:space:]]*-->[[:space:]]*$/d' \
    | sed '/^$/d' | head -n 1)"
  if [ -z "${body}" ]; then
    printf 'changelog-aggregate: empty fragment: %s\n' "${f}" >&2
    exit 1
  fi
  body="${body#- }"
  bullets="${bullets}- \`${sha}\` — ${body}
"
done <<EOF
${rows}
EOF

if [ "${APPLY}" -eq 0 ]; then
  printf '%s' "${bullets}"
  exit 0
fi

# --apply path: insert under the first "### Added" inside "## [Unreleased]".
bullets_file="$(mktemp -t changelog-aggregate.XXXXXX)"
trap 'rm -f "${bullets_file}"' EXIT
printf '%s' "${bullets}" >"${bullets_file}"

awk -v addfile="${bullets_file}" '
  BEGIN {
    in_unrel = 0
    inserted = 0
  }
  /^## \[Unreleased\]/ { in_unrel = 1; print; next }
  /^## \[/ && in_unrel { in_unrel = 0 }
  in_unrel && !inserted && /^### Added/ {
    print
    print ""
    while ((getline line < addfile) > 0) {
      print line
    }
    close(addfile)
    inserted = 1
    next
  }
  { print }
  END {
    if (!inserted) {
      print "changelog-aggregate: no `### Added` under `[Unreleased]`" > "/dev/stderr"
      exit 1
    }
  }
' "${CHANGELOG}" >"${CHANGELOG}.tmp"

mv "${CHANGELOG}.tmp" "${CHANGELOG}"

# Remove the consumed fragments. README.md stays.
while IFS=$'\t' read -r _ts _sha f; do
  if [ -n "${f}" ] && [ -f "${f}" ]; then
    rm -- "${f}"
  fi
done <<EOF
${rows}
EOF

printf 'changelog-aggregate: inserted %d bullet(s) into %s\n' \
  "$(printf '%s' "${rows}" | grep -c .)" "${CHANGELOG}"
