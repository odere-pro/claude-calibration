[← README](../README.md) · [Glossary](../glossary.md)

# `AGENTS.md` — the open standard, and how it maps to Claude Code

`AGENTS.md` is a vendor-neutral, open convention for giving AI coding agents the context they need
to work in a repository — a **README for agents** (the human-facing `README.md` stays for people).
Reference: <https://agents.md>. This page covers the standard, then how Claude Code relates to it.

## What it is

- One instruction file that many tools read, instead of a bespoke file per tool. Supporters
  (per agents.md) include OpenAI Codex / Codex CLI, Google Jules, Google Gemini CLI, Cursor, Aider,
  goose, opencode, Zed, Warp, VS Code / GitHub Copilot, Devin, JetBrains Junie, Amp, RooCode, Kilo
  Code, Phoenix, Semgrep, Windsurf, Augment Code, Ona, UiPath, Factory, and others.
- Plain Markdown — "use any headings you like; the agent simply parses the text you provide." No
  schema, no required fields, no build step. No official linter.
- Lives at the **repo root** for the project-wide file. In a monorepo, additional `AGENTS.md` files
  can live in subdirectories — agents "automatically read the nearest file in the directory tree, so
  the closest one takes precedence." "Explicit user chat prompts override everything."
- Complements `README.md`: README = quick starts, project descriptions, contribution guidelines for
  humans; `AGENTS.md` = the extra, sometimes detailed context agents need. Keep READMEs concise.

A pragmatic section template (use what applies, delete the rest):

```markdown
# <Project Name>

## Project overview        — what this repo is, the stack, the architecture in a sentence, where the important code lives
## Setup & environment     — prerequisites, bootstrap command, required env vars (point at .env.example — never put secrets here)
## Build & run             — dev server, production build, common scripts
## Testing                 — run the full suite / a single test, coverage expectations, "always run X before a PR"
## Code style & conventions — formatter/linter command, naming, file organization, patterns vs anti-patterns
## Project layout          — key directories (note any nested AGENTS.md), generated files not to hand-edit
## Git & PR guidelines     — branch naming, commit format, required checks before pushing
## Security & safety       — secrets handling, off-limits files, destructive commands
## Gotchas                 — flaky tests, slow steps, known-broken things, non-obvious decisions
```

## How Claude Code relates to `AGENTS.md`

**Claude Code reads `CLAUDE.md`, not `AGENTS.md`.** ([Memory docs](https://code.claude.com/docs/en/memory).)
To use the open-standard file with Claude Code, [import it](../glossary.md) from `CLAUDE.md`:

```markdown
@AGENTS.md

## Claude Code
Claude-specific instructions can go here, below the import.
```

…or symlink (when you don't need Claude-specific additions):

```bash
ln -s AGENTS.md CLAUDE.md
# monorepo: per package
for d in apps/* packages/*; do (cd "$d" && [ -f AGENTS.md ] && ln -sf AGENTS.md CLAUDE.md); done
```

On Windows a symlink needs Administrator privileges or Developer Mode — use the `@AGENTS.md` import
there. Make the open-standard file (`AGENTS.md`) the real file and `CLAUDE.md` the link, so the
portable artifact is the source of truth. Running `/init` in a repo that already has `AGENTS.md`
reads it (and `.cursorrules`, `.windsurfrules`, …) and folds the relevant parts into the generated
`CLAUDE.md`. Other tools (Codex, Cursor, …) read `AGENTS.md` directly — no import needed; the
import/symlink exists only because Claude Code looks for `CLAUDE.md`.

### Once imported — behavioral equivalence

| Behavior | `AGENTS.md` (open standard) | Claude Code (via `CLAUDE.md` ⟵ `@AGENTS.md` / symlink) | Same? |
|----------|------------------------------|---------------------------------------------------------|-------|
| Native read | agents read `AGENTS.md` at the repo root directly | reads `CLAUDE.md`; the import makes `AGENTS.md` content arrive at session start | ⚠️ needs the one-line import |
| Discovery | agent reads the file at the repo root | `CLAUDE.md` files loaded at session start | ✅ |
| Nesting / monorepo | nearest `AGENTS.md` to the edited file wins; parent applies otherwise | walks **up** the dir tree from cwd; all `CLAUDE.md`/`CLAUDE.local.md` found are concatenated (root → cwd, closer read last); subdirectory files load on demand | ✅ |
| Multiple levels combine | root + nested both inform the agent | all discovered files concatenated into context | ✅ |
| Explicit prompt vs. file | a direct chat prompt overrides the file | a chat instruction overrides the memory file | ✅ |
| "Run the checks" | programmatic steps are expected to actually run | Claude runs the commands, doesn't just acknowledge them | ✅ |
| Plain Markdown, no schema | any headings; nothing mandatory | same — free-form Markdown | ✅ |
| Includes / references | some tools support `@path` imports | `@path` imports work in `CLAUDE.md` (and what it imports — `@AGENTS.md`, `~/.claude/rules/**`); max depth 5 hops | ✅ |
| Path-scoped rules | not part of the standard | extra: `.claude/rules/*.md` with `paths:` frontmatter load only for matching files (see [`features/rules.md`](../features/rules.md)) | ➕ Claude-only |

### What has no `AGENTS.md` counterpart

`AGENTS.md` is scoped to *instructions*. Claude Code's other features have no `agents.md`
equivalent and live under `.claude/`: [Settings](../features/settings.md), [Hooks](../features/hooks.md),
[Subagents](../features/subagents.md), [Skills](../features/skills.md) (incl. legacy
[commands](../features/commands.md)), [Plugins](../features/plugins.md), [MCP](../features/mcp.md)
config (`.mcp.json` — MCP itself is an open protocol, but the config file is per-tool), keybindings,
status line. Keep `AGENTS.md` for the portable "how this repo works"; the rest is Claude-specific.

## Do / don't

**Do** — keep it concise and skimmable; put exact commands in backticks; update it in the same PR as
the workflow change; use nested files in monorepos rather than one giant root file; make `AGENTS.md`
the real file and `CLAUDE.md` the import/symlink.
**Don't** — put secrets, tokens, or internal URLs in it; restate the README; write aspirational rules
you don't enforce (agents follow them literally); let it rot.

## Sources

- AGENTS.md open standard — <https://agents.md>
- Claude Code memory / `AGENTS.md` import / `@path` imports / `.claude/rules/` — <https://code.claude.com/docs/en/memory>
- Commands (`/init` reading `AGENTS.md` / other tool configs) — <https://code.claude.com/docs/en/commands>
- See also `features/claude-md.md` and `general-setup.md` in this set.
