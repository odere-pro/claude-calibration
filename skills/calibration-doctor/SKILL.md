---
name: calibration-doctor
description: >-
  Fast structural health check for a Claude Code setup. Detects broken config — JSON that
  doesn't parse, hook scripts that are missing or non-executable, subagent/skill files with
  malformed frontmatter, MCP servers whose command can't be found, and .gitignore that's
  missing `.claude/calibration/`. Prints a terse triage list (broken / warn / ok) in under
  a few seconds. Does NOT grade quality against the rubric — that's `/claude-calibration:calibration-audit`.
  Use this as a smoke check ("does the setup work?") before running anything heavier, or as
  a CI step that flags drift without spending a full audit.
argument-hint: "[--verbose]"
disable-model-invocation: true
model: haiku
allowed-tools: Read, Grep, Glob, Bash(bash:*), Bash(date:*), Bash(ls:*)
---

```!
echo "=== calibration-doctor preprocessing ==="
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SCRIPT="${CLAUDE_SKILL_DIR}/scripts/doctor.sh"
echo "PROJECT_DIR=$PROJECT_DIR"
echo "DOCTOR_SCRIPT=$SCRIPT"
if [ -x "$SCRIPT" ] || [ -f "$SCRIPT" ]; then
  echo "--- doctor.sh output (TSV) ---"
  bash "$SCRIPT" "$PROJECT_DIR" 2>&1
  echo "--- end doctor.sh output ---"
else
  echo "DOCTOR_SCRIPT_NOT_FOUND=$SCRIPT"
fi
echo "=== end preprocessing ==="
```

# /claude-calibration:calibration-doctor

You are the **calibration doctor**. The preprocessing block above has already run
`scripts/doctor.sh "$PROJECT_DIR"` and inlined its TSV output between
`--- doctor.sh output (TSV) ---` markers. Your job is to **format and print** that output as
a triage list. Do not run any scripts yourself; do not write any files.

The TSV is one row per check: `<check>\t<status>\t<detail>`, where `status` is one of:

- `ok` — check passed.
- `warn` — non-blocking concern (style threshold, optional setup).
- `broken` — config likely doesn't work (missing file, parse error, missing required field).

Optional argument: `$ARGUMENTS` — if it contains the token `--verbose`, include the `ok`
rows in the output. Otherwise hide them and only show the counts.

## Output format

Always start with a one-line header:

```
calibration-doctor · <PROJECT_DIR>
```

Then group findings by status, **broken first**, then `warn`. Each row is
`<status-glyph> <check> — <detail>`:

```
✗ broken: agent:foo.md — missing required frontmatter: tools
✗ broken: hook:format.sh — script not executable (chmod +x): ./hooks/format.sh
! warn:   claude-md:size — 837 lines (>800 — split or trim; see calibrate-claude-md)
! warn:   mcp:linear — command not on PATH: linear-mcp (server may not start)
```

If `$ARGUMENTS` contains `--verbose`, also list the `ok` rows under a `Healthy:` heading.

Close with a count line and a `→ Next:` pointer:

```
<B> broken · <W> warn · <O> ok
→ <pointer>
```

Where the pointer depends on what fired:

- If any `broken` rows: `→ Fix the broken items first, then re-run /claude-calibration:calibration-doctor.`
- Else if any `warn` rows: `→ /claude-calibration:calibration-audit for the full rubric audit, or /calibrate to plan fixes.`
- Else: `→ Setup looks healthy. /claude-calibration:calibration-audit for a quality-grade rubric pass.`

If the preprocessing block reported `DOCTOR_SCRIPT_NOT_FOUND=...`, print:

```
calibration-doctor: scripts/doctor.sh not found.
→ The plugin install may be incomplete. Re-install or run /reload-plugins.
```

and stop.

## What this skill does NOT do

- It does not enumerate the full rubric (Must/Should items per feature). That's
  `/claude-calibration:calibration-audit`.
- It does not score quality. A "ok" here means "parses and resolves", not "well-designed".
- It does not write any files. It is pure read-only triage.
- It does not run lint scripts from the per-feature `calibrate-<feature>` bundles. Those
  surface rubric quality issues; this skill surfaces structural breakage. Different jobs.

## When to run

- **First-time setup, after `/claude-calibration:calibration-onboarding`** — confirm the
  setup actually parses before kicking off a full audit.
- **Pre-commit / pre-push smoke check** — a few seconds, no LLM cost on the script itself
  (haiku formats the output). Catches a typo'd settings.json or a non-executable hook script
  before it bites in a real session.
- **After a hand-edit of `.claude/**` files** — fast confirmation you didn't break
  anything structurally.
- **As a CI gate** — bundle's exit code is always 0, so parse the TSV directly in CI if you
  want a fail-on-broken contract.

## Hard rules

- You print only what the doctor script emitted, formatted for the user. Do not invent
  checks or extrapolate from filenames the script didn't visit.
- You never run the doctor script yourself — the preprocessing block already did. If its
  output is missing, surface the error and stop.
- You never write any file. This skill is read-only by contract.
