#!/usr/bin/env bash
# G17 — the glossary vocabulary is defined AND used consistently. (CRITICAL)
#   (a) `agent` and `subagent` are two DISTINCT bold entries (they coexist — a subagent is an agent
#       that runs in its own context window).
#   (b) every term in power-words.txt has a bold `**term**` definition in the glossary.
#   (c) no unambiguously-wrong phrase from forbidden-terms.txt appears in shipped/author prose
#       (this is the layer that catches USAGE drift, e.g. a worker subagent relabelled a plain agent).
# Power words steer skills/agents; the glossary is their single source of truth.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

GLOSSARY="docs/glossary.md"
WORDS="tests/gates/power-words.txt"
FORBIDDEN="tests/gates/forbidden-terms.txt"
# Surfaces scanned for usage drift: plugin artifacts, docs, and .claude config incl. CLAUDE.md files.
SCAN_DIRS="docs skills agents rules hooks .claude CLAUDE.md"
fail=0

for f in "$GLOSSARY" "$WORDS" "$FORBIDDEN"; do
  [ -f "$f" ] || { echo "  FAIL: missing $f"; echo "G17 glossary-consistency: FAIL"; exit 1; }
done

# (a) agent and subagent must each be their own bold list entry (distinct lemmas)
for t in Agent Subagent; do
  grep -qiE "^- \*\*${t}\*\*" "$GLOSSARY" \
    || { echo "  FAIL: $GLOSSARY has no distinct '**${t}**' entry (agent/subagent must coexist)"; fail=1; }
done

# (b) every catalogued power word has a bold definition in the glossary
while IFS= read -r term; do
  case "$term" in ''|'#'*) continue ;; esac
  grep -qiF -- "**${term}**" "$GLOSSARY" \
    || { echo "  FAIL: power word '${term}' is not defined (**${term}**) in $GLOSSARY"; fail=1; }
done < "$WORDS"

# (c) no forbidden phrase in prose (skip examples/templates fixtures, worktrees, URL lines, and
#     transient gitignored run artifacts under .claude/calibration/ — generated output, not source
#     prose; note .claude/calibration shares its basename with the shipped skills/calibration/ dir,
#     so it must be excluded by path, not --exclude-dir)
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  case "$line" in *' => '*) : ;; *) echo "  FAIL: malformed forbidden rule (no ' => '): $line"; fail=1; continue ;; esac
  bad="${line%% => *}"
  good="${line##* => }"
  grep -qiF -- "$good" "$GLOSSARY" \
    || { echo "  FAIL: forbidden-terms canonical '$good' not found in $GLOSSARY"; fail=1; }
  hits="$(grep -rniE --include='*.md' --exclude-dir=examples --exclude-dir=templates --exclude-dir=worktrees \
            -- "$bad" $SCAN_DIRS 2>/dev/null | grep -vE '://' | grep -vE '^\.claude/calibration/' || true)"
  if [ -n "$hits" ]; then
    while IFS= read -r h; do
      [ -n "$h" ] || continue
      echo "  FAIL: $h  (use '$good')"
      fail=1
    done <<EOF
$hits
EOF
  fi
done < "$FORBIDDEN"

if [ "$fail" -ne 0 ]; then echo "G17 glossary-consistency: FAIL"; exit 1; fi
echo "G17 glossary-consistency: ok"
