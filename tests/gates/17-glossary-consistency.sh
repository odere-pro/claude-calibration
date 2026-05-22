#!/usr/bin/env bash
# G17 — docs/glossary.md defines the power-word vocabulary. (CRITICAL)
#   (a) `agent` and `subagent` are two DISTINCT bold entries (they coexist — a subagent is an agent
#       that runs in its own context window).
#   (b) every term in power-words.txt has a bold `**term**` definition in the glossary.
# Power words steer skills/agents; the glossary is their single source of truth, so it must define
# them. This is a structural check on the glossary — it does NOT police prose elsewhere.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

GLOSSARY="docs/glossary.md"
WORDS="tests/gates/power-words.txt"
fail=0

[ -f "$GLOSSARY" ] || { echo "  FAIL: missing $GLOSSARY"; echo "G17 glossary-consistency: FAIL"; exit 1; }
[ -f "$WORDS" ]    || { echo "  FAIL: missing $WORDS";    echo "G17 glossary-consistency: FAIL"; exit 1; }

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

if [ "$fail" -ne 0 ]; then echo "G17 glossary-consistency: FAIL"; exit 1; fi
echo "G17 glossary-consistency: ok"
