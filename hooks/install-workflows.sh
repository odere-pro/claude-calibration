#!/usr/bin/env bash
# install-workflows.sh — SessionStart hook.
#
# There is no native plugin component type for `Workflow` scripts, so this hook makes the plugin's
# bundled workflow(s) available by copying them into the project's `.claude/workflows/` registry
# (where the `Workflow` tool / `/workflows` resolves named workflows). That is how the parallel-audit
# workflow gets "installed together with the plugin".
#
# Policy (never clobbers user edits):
#   - destination missing            -> copy it in, print a one-line "installed" notice
#   - destination identical          -> silent no-op (near zero-cost: one cmp per file)
#   - destination present but differs -> print a one-line "differs / delete to refresh" notice, do NOT overwrite
#
# Never blocks the session: always exits 0. No network (gate G12).
set -u

# Self-locate: the command is invoked as ${CLAUDE_PLUGIN_ROOT}/hooks/install-workflows.sh, so dirname
# of an absolute path is reliable regardless of which env vars the hook runtime exports.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
[ -n "${SCRIPT_DIR}" ] || exit 0
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." 2>/dev/null && pwd || true)"
[ -n "${PLUGIN_ROOT}" ] || exit 0

SRC_DIR="${PLUGIN_ROOT}/workflows"
PROJECT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
DEST_DIR="${PROJECT}/.claude/workflows"

# Nothing bundled to install -> nothing to do.
[ -d "${SRC_DIR}" ] || exit 0

shopt -s nullglob
sources=("${SRC_DIR}"/*.mjs)
[ "${#sources[@]}" -gt 0 ] || exit 0

mkdir -p "${DEST_DIR}" 2>/dev/null || exit 0

for src in "${sources[@]}"; do
  base="$(basename "${src}")"
  dest="${DEST_DIR}/${base}"
  if [ ! -f "${dest}" ]; then
    if cp "${src}" "${dest}" 2>/dev/null; then
      printf '[calibration] installed workflow: .claude/workflows/%s (run via /workflows)\n' "${base}" >&2
    fi
  elif ! cmp -s "${src}" "${dest}"; then
    printf '[calibration] .claude/workflows/%s differs from the bundled version — delete it and restart to refresh.\n' "${base}" >&2
  fi
done

exit 0
