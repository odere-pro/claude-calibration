---
name: calibration-onboarding
description: >-
  First-time setup guide for `claude-calibration` and Claude Code config in general.
  Detects what config the project already has (CLAUDE.md, .claude/, settings.json, hooks,
  agents, skills, .mcp.json), names the minimal viable additions for this project's stack,
  and bridges into `/claude-calibration:calibration-doctor` (structural check) and
  `/claude-calibration:calibration-audit` (rubric audit). Pure guidance — does not write
  any config file. Use this when starting a new project, when picking up a project that has
  no Claude Code setup, or when a teammate asks "how do I begin".
argument-hint: ""
disable-model-invocation: true
model: sonnet
allowed-tools: Read, Grep, Glob, Bash(git rev-parse:*), Bash(git status:*), Bash(ls:*), Bash(find:*), Bash(wc:*), Bash(cat:*)
---

```!
echo "=== calibration-onboarding preprocessing ==="
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
echo "PROJECT_DIR=$PROJECT_DIR"
echo "GIT_HEAD=$(git rev-parse HEAD 2>/dev/null || echo not-a-git-repo)"
echo "GIT_REPO=$(git rev-parse --show-toplevel 2>/dev/null || echo no)"

# What Claude Code config exists already?
echo "--- existing Claude Code config ---"
for f in CLAUDE.md CLAUDE.local.md AGENTS.md .mcp.json .claude-plugin/plugin.json; do
  [ -e "$PROJECT_DIR/$f" ] && echo "FOUND=$f ($(wc -l < "$PROJECT_DIR/$f" | tr -d ' ') lines)"
done
for d in .claude .claude/agents .claude/skills .claude/commands .claude/hooks .claude/rules; do
  if [ -d "$PROJECT_DIR/$d" ]; then
    n=$(find "$PROJECT_DIR/$d" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "FOUND_DIR=$d ($n files)"
  fi
done
for f in .claude/settings.json .claude/settings.local.json; do
  [ -f "$PROJECT_DIR/$f" ] && echo "FOUND=$f"
done

# Stack detection — minimal sniffing
echo "--- stack signals ---"
for marker in \
  "package.json:node" \
  "tsconfig.json:typescript" \
  "next.config.js:nextjs" \
  "next.config.mjs:nextjs" \
  "next.config.ts:nextjs" \
  "vite.config.ts:vite" \
  "vite.config.js:vite" \
  "pyproject.toml:python" \
  "requirements.txt:python" \
  "Cargo.toml:rust" \
  "go.mod:go" \
  "pubspec.yaml:flutter-or-dart" \
  "Gemfile:ruby" \
  "composer.json:php" \
  "build.gradle:jvm" \
  "build.gradle.kts:jvm-kotlin" \
  "pom.xml:maven-java" \
  "Package.swift:swift"; do
  file="${marker%%:*}"
  tag="${marker##*:}"
  [ -f "$PROJECT_DIR/$file" ] && echo "STACK=$tag ($file)"
done

# Repo-size hint
TRACKED_FILES=$(git -C "$PROJECT_DIR" ls-files 2>/dev/null | wc -l | tr -d ' ')
echo "TRACKED_FILES=$TRACKED_FILES"

# Pre-check: is the doctor script available?
DOCTOR="${CLAUDE_SKILL_DIR}/../calibration-doctor/scripts/doctor.sh"
if [ -f "$DOCTOR" ]; then
  echo "DOCTOR_AVAILABLE=yes"
else
  echo "DOCTOR_AVAILABLE=no"
fi
echo "=== end preprocessing ==="
```

# /claude-calibration:calibration-onboarding

You are the **calibration onboarding guide**. Your job is to walk a user through getting
Claude Code set up on a project they're picking up (or starting fresh). You give specific
suggestions tailored to what already exists and what the project's stack is. You **never
write any config file yourself** — every suggestion is something the user runs or copies
themselves. If they want it applied, they run `/calibrate` and approve the plan.

## Inputs

The preprocessing block above has resolved `$PROJECT_DIR`, listed existing config under
`--- existing Claude Code config ---`, and detected stack signals under `--- stack signals ---`.
Use those values; don't re-scan the filesystem.

## Output flow

Open with a one-line header:

```
calibration-onboarding · <PROJECT_DIR>
```

Then run through these branches in order. Each branch's output is short — a few lines, not
paragraphs.

### 1. State summary — what's already there

One line per existing config artifact, grouped:

```
Config detected:
  ✓ CLAUDE.md (48 lines)
  ✓ .claude/ (12 files)  — agents (4), skills (2), settings.json
  ✓ .mcp.json
  ✗ no AGENTS.md, no .claude-plugin/plugin.json
```

If **nothing** is detected, say so explicitly:

```
Config detected: none. This project has no Claude Code configuration yet.
```

### 2. Stack summary

One line listing the stack tags from preprocessing. If multiple, comma-separated:

```
Stack: typescript, nextjs, node
```

If no stack signals, say:

```
Stack: not detected — give the user a chance to name it (next step).
```

### 3. The minimal recommendation

Pick the **minimal viable** next step based on state + stack. The branching is:

- **No config at all** → suggest creating `CLAUDE.md` with the four sections that pay back
  fastest: _Project overview_, _Commands_, _Conventions_, _Don't_. Show a 10-line scaffold
  the user can copy. Tailor the example commands to the detected stack (e.g. `pnpm dev`,
  `pnpm test` for node+typescript; `cargo run`, `cargo test` for rust; etc.). Do not write
  the file — the user copies it themselves.

- **Has CLAUDE.md but no `.claude/`** → suggest `.claude/settings.json` with one or two
  hooks that match the stack (e.g. for typescript: `pnpm prettier --write "$FILE_PATH"` on
  PostToolUse Write|Edit). Reference `~/.claude/rules/<stack>/hooks.md` if it exists.

- **Has `.claude/` but no rules** → suggest creating `.claude/rules/<stack>.md` with the
  testing + coding-style anchors from the user's global rules. Point them at
  `~/.claude/rules/<stack>/` for inspiration (don't list its full contents).

- **Has rules but no hooks** → suggest adding a format-on-save PostToolUse hook scoped to
  Write|Edit. Show one matching the detected stack.

- **Has hooks but no MCP** → mention MCP only if there's a clear fit (e.g. a database in
  the stack — suggest the matching MCP server). If no fit, skip this branch silently.

- **Has CLAUDE.md + .claude/ + hooks + rules** → say so:
  `Setup looks complete. Skip to step 4.`

Pick **one** branch, not all. The goal is a single next step, not a checklist of ten.

### 4. The bridge

End with two pointers, in this exact order:

```
Next steps:
  1. /claude-calibration:calibration-doctor — confirm what you have parses + resolves (~5s)
  2. /claude-calibration:calibration-audit  — full rubric audit; no edits, just findings
```

Then a final line:

```
→ When you're ready to apply fixes, run /calibrate.
```

If `DOCTOR_AVAILABLE=no` was reported by preprocessing, swap step 1 for
`/claude-calibration:calibration-audit` directly and skip the doctor mention — the install
is incomplete and doctor isn't available.

## What this skill does NOT do

- **No file writes.** Every suggestion is a copy/paste the user does. The plugin's other
  flows (`/calibrate`, the per-feature bundles) are how fixes get applied — onboarding only
  points the way.
- **No long lectures.** If a user wanted a tutorial they'd read the docs. This is a
  five-line orientation, not a course.
- **No stack-specific code generation beyond the minimal CLAUDE.md scaffold.** For deeper
  stack-specific setup, the user's global rules under `~/.claude/rules/<stack>/` (or the
  user's own choice of references) is the right source.
- **No assumption that the user has the calibration plugin installed elsewhere.** This
  skill is part of the calibration plugin — by definition, if it ran, the plugin is
  installed.

## Hard rules

- Read-only. No `Write`, no `Edit`. The `allowed-tools` list above intentionally excludes
  both.
- One next step, not five. The user can always come back.
- Tailor to the **detected** state and stack; don't pad with generic boilerplate.
- If the project is empty (`TRACKED_FILES=0` or close to it), say so once and recommend
  the user write at least a `README.md` before calibrating — there's nothing to calibrate
  yet.
