# Claude Code — Project Configuration

How to configure Claude Code _for a repository_. This compiles the project-scoped slice of
`claude-structure.md` (what files Claude reads) with `agents-md-structure.md` (how the
instruction file works), into one practical guide. Validated against the official docs — see
*Sources* at the bottom.

## 1. What lives in a project

Everything below is optional — create only what you need. Committed files are shared with the
team; `.local.*` files are git-ignored and personal.

```text
<project-root>/
├── CLAUDE.md                    # project memory / instructions — committed, shared (or ./.claude/CLAUDE.md)
├── CLAUDE.local.md              # personal project memory — add to .gitignore
├── AGENTS.md                    # open-standard file — read by Claude Code ONLY if CLAUDE.md does `@AGENTS.md`
│                                #   (or is a symlink to it). Other tools read AGENTS.md directly.
├── .mcp.json                    # project-scoped MCP servers — committed
└── .claude/
    ├── CLAUDE.md                # alternative location for project memory
    ├── settings.json            # project settings: permissions, env, hooks — committed
    ├── settings.local.json      # personal project settings — git-ignored
    ├── rules/                   # auto-loaded *.md rule files; optional `paths:` frontmatter scopes to globs; symlink-able
    ├── agents/                  # project-scoped subagents (*.md: YAML frontmatter + body=system prompt)
    ├── commands/                # project-scoped slash commands (*.md — legacy form; prefer skills/)
    ├── skills/                  # project-scoped skills — <name>/SKILL.md (+ supporting files)
    └── hooks/                   # project-scoped hook scripts (entries go under `hooks` in settings.json)
```

Plugins (installed at the user level) layer the same building blocks — `skills/`, `commands/`,
`agents/`, `hooks/`, `.mcp.json`, `.lsp.json`, `monitors/`, `bin/` — on top of a project. See
`claude-structure.md` for plugin layout.

## 2. The instruction file — `CLAUDE.md` (and the `AGENTS.md` bridge)

**Claude Code reads `CLAUDE.md`, not `AGENTS.md`.** If your repo uses the open-standard
`AGENTS.md` for other tools, bridge it from `CLAUDE.md` — import it (`@AGENTS.md`, optionally with
Claude-specific lines below) or symlink:

```bash
ln -s AGENTS.md CLAUDE.md     # if you don't need Claude-specific additions (on Windows, use the @AGENTS.md import)
```

`CLAUDE.md` is loaded as a memory file: delivered as a user message after the system prompt,
treated as context rather than enforced configuration.

Properties:

- **Plain Markdown.** Any headings; nothing is mandatory. No schema, no linter, no build step.
- **Discovery.** Files are found by walking **up** the directory tree from cwd and **concatenated**
  (ordered filesystem-root → cwd, so the closest file is read last; `CLAUDE.local.md` is appended
  after `CLAUDE.md` at each level). Subdirectory `CLAUDE.md` files *below* cwd load on demand when
  Claude reads files there. `.claude/rules/*.md` load at the same priority as `.claude/CLAUDE.md`.
- **A direct prompt wins.** Explicit instructions in the chat override the file.
- **Programmatic checks are real.** If the file says "run `pnpm test` before committing", Claude is
  expected to actually run it, not just acknowledge it. For something that *must* run at a fixed
  point, use a [hook](https://code.claude.com/docs/en/hooks) instead.
- **Keep it short.** Target **under ~200 lines** per `CLAUDE.md` — longer files consume more context
  and reduce adherence. Split big content into [`.claude/rules/`](https://code.claude.com/docs/en/memory#organize-rules-with-claude-rules)
  (optionally path-scoped) or `@path` imports (imports still load at launch; they organize, they
  don't shrink context).
- **Be specific and structured.** "Use 2-space indentation" beats "format code properly"; use headers
  and bullets. Block-level HTML comments are stripped before injection — use them for human-only notes.
- **`@path` imports.** Relative paths resolve against the importing file; recursive imports allowed,
  max depth 5 hops; first external import triggers an approval dialog.

### Recommended structure

A pragmatic template — use the sections that apply, delete the rest:

```markdown
# <Project Name>

## Project overview
One or two paragraphs: what this repo is, the stack, the architecture in a sentence,
where the important code lives.

## Setup & environment
- Prerequisites (language/runtime versions, package manager, system deps)
- Bootstrap: `<install command>`
- Required env vars / where to get them (never put secrets here — point at a vault or `.env.example`)

## Build & run
- Dev server: `<command>`
- Production build: `<command>`
- Common scripts and what they do

## Testing
- Run the full suite: `<command>`
- Run a single test / package: `<command>`
- Coverage expectations, where tests live, naming conventions
- "Always run X before opening a PR."

## Code style & conventions
- Formatter / linter and how to run them (`<command>`)
- Naming, file organization, import ordering
- Patterns to follow; anti-patterns to avoid

## Project layout
- `src/...` — ...
- `packages/...` — ... (note any nested CLAUDE.md / AGENTS.md)
- Generated files / things not to hand-edit

## Git & PR guidelines
- Branch naming, commit message format
- Required checks before pushing

## Security & safety
- Secrets handling, what must never be committed
- Files/dirs that are off-limits or destructive commands

## Gotchas / institutional knowledge
- Flaky tests, slow steps, known-broken things
```

### Monorepo layout

```text
repo/
├── CLAUDE.md                 # repo-wide defaults  (or a symlink to AGENTS.md, or `@AGENTS.md`)
├── apps/
│   ├── web/
│   │   └── CLAUDE.md         # adds to (loads after) the root file when Claude works under apps/web/
│   └── api/
│       └── CLAUDE.md
└── packages/
    └── ui/
        └── CLAUDE.md
```

Editing `apps/web/src/Foo.tsx`, Claude has loaded the root `CLAUDE.md` and reads `apps/web/CLAUDE.md`
on demand. Closer files are read last. Use `claudeMdExcludes` (in `.claude/settings.local.json`) to
skip other teams' ancestor `CLAUDE.md` files.

---

## 3. Settings — `.claude/settings.json`

JSON config for harness behavior in this repo. Common keys: `permissions`, `env`, `model`, `hooks`,
`statusLine`, `editorMode`, `autoUpdatesChannel`, `cleanupPeriodDays`, `alwaysThinkingEnabled`,
`claudeMdExcludes`, `skillOverrides` — see the [full list](https://code.claude.com/docs/en/settings).
Two files:

| File | Scope | Committed? |
|------|-------|-----------|
| `.claude/settings.json` | Team — applies to everyone on the repo | ✅ yes |
| `.claude/settings.local.json` | Personal — your machine only | ❌ git-ignored |

### Precedence (highest → lowest)

1. **Managed** (enterprise / policy `managed-settings.json`) — cannot be overridden
2. **Command-line arguments**
3. **Local** — `.claude/settings.local.json`
4. **Project** — `.claude/settings.json`
5. **User** — `~/.claude/settings.json`

---

## 4. Subagents — `.claude/agents/*.md`

One Markdown file per subagent: YAML frontmatter for config, the Markdown **body is the system
prompt** (the subagent gets only that plus basic environment details — not the full Claude Code
system prompt). Only `name` and `description` are required; other fields: `tools`, `disallowedTools`,
`model` (defaults to `inherit`), `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`,
`memory`, `background`, `effort`, `isolation`, `color`, `initialPrompt`. If `tools` is omitted the
subagent **inherits all tools** (including MCP tools); use `tools` (allowlist) or `disallowedTools`
(denylist) to restrict. Precedence on name clash: **managed > `--agents` flag > project
`.claude/agents/` > user `~/.claude/agents/` > plugin `agents/`**. Built-in subagents: `Explore`,
`Plan`, `general-purpose`. Plugin subagents ignore `hooks`, `mcpServers`, and `permissionMode`. Not
loaded from `--add-dir` directories.

---

## 5. Slash commands / skills — `.claude/commands/*.md` and `.claude/skills/<name>/SKILL.md`

Custom commands have been **merged into skills**: `.claude/commands/deploy.md` and
`.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way. Existing
`commands/*.md` files keep working; skills add a directory for supporting files, more frontmatter,
and automatic (model-)invocation. If a skill and a command share a name, the skill wins. Project
commands/skills join the union of `~/.claude/commands` + `~/.claude/skills` + plugin
commands/skills; plugin entries are namespaced `plugin:name`. Not loaded from `--add-dir`. See §6.

---

## 6. Skills — `.claude/skills/<skill>/SKILL.md`

One directory per skill; `SKILL.md` (required) = YAML frontmatter + Markdown instructions; optional
supporting files (`reference.md`, `examples.md`, `scripts/`) are loaded/run only when referenced.
All frontmatter fields are optional; `description` is recommended. Key fields: `name` (lowercase
letters/numbers/hyphens, ≤ 64 chars; defaults to the directory name), `description` (what + when to
use it — Claude routes on this), `when_to_use`, `argument-hint`, `arguments`,
`disable-model-invocation` (only you can invoke), `user-invocable: false` (only Claude can invoke),
`allowed-tools`, `model`, `effort`, `context: fork` (+ `agent`), `hooks`, `paths`, `shell`.
Substitutions: `$ARGUMENTS`, `$N`, `$name`, `${CLAUDE_SESSION_ID}`, `${CLAUDE_SKILL_DIR}`, etc.;
`` !`cmd` `` injects shell-command output before Claude sees the skill.

Caps that matter: combined `description` + `when_to_use` is truncated at **1,536 characters** in the
skill listing (configurable via `maxSkillDescriptionChars`); the skill listing budget is ~1% of the
model's context window (configurable via `skillListingBudgetFraction`). Keep `SKILL.md` **under ~500
lines** — move detail to supporting files. Active skill set = `~/.claude/skills/` + project
`.claude/skills/` + `.claude/skills/` in any `--add-dir` directory + enabled plugins' `skills/`.
Name clash: enterprise > personal > project; plugin skills namespaced. Visibility tuning:
`skillOverrides` setting (`/skills` menu writes it) and `disable-model-invocation` / `user-invocable`.

---

## 7. Hooks — `.claude/hooks/` + `settings.json` → `hooks`

Hook *scripts* live anywhere (commonly `.claude/hooks/`); hook *entries* (event → matcher → handler)
go under the `hooks` key in a `settings.json` (user / project / local / managed) or a plugin's
`hooks/hooks.json`, or in skill/agent frontmatter. There are many events — tool events
(`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `PermissionRequest`,
`PermissionDenied`), turn events (`UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`),
session events (`SessionStart`, `SessionEnd`, `Setup`, `InstructionsLoaded`), agent/team events
(`SubagentStart`, `SubagentStop`, …), and more. Exit codes: **0** = success (stdout parsed for JSON
output); **2** = blocking error (stderr fed back to Claude); **any other code** = non-blocking error.
Only exit `2` blocks — `exit 1` is treated as non-blocking. The `matcher` filters which occurrences
fire (tool name, session-start reason, etc.); `*`/empty/omitted matches all; an optional `if` field
adds permission-syntax filtering on tool events.

---

## 8. MCP servers — `.mcp.json`

Project-scoped Model Context Protocol servers, committed so the team shares them. Effective set =
`~/.claude.json` (user + per-project local) + project `.mcp.json` + every enabled plugin's `.mcp.json`
+ enterprise `managed-mcp.json`. A subagent can also declare servers via the `mcpServers` frontmatter
field — defining one there (rather than in `.mcp.json`) keeps its tool descriptions out of the main
conversation's context. MCP itself is an open protocol; the servers are reusable across MCP-aware
tools even though the config filename differs per tool.

---

## 9. Do / don't

**Do**
- Keep `CLAUDE.md` concise (< ~200 lines), concrete, structured; push big content to `.claude/rules/`.
- Put exact commands in backticks so they can be run verbatim.
- Commit team config (`CLAUDE.md`, `.claude/settings.json`, `.mcp.json`, `rules/`, `agents/`,
  `commands/`, `skills/`, `hooks/`); keep personal config in `.claude/settings.local.json` and
  `CLAUDE.local.md` (git-ignored).
- In monorepos use nested `CLAUDE.md` (or `AGENTS.md`) per package, not one sprawling root file.
- Update the instruction file in the same PR that changes the workflow it describes.

**Don't**
- Don't put secrets, tokens, or internal URLs in any committed file — point at `.env.example` or a vault.
- Don't restate the README; link to it.
- Don't write aspirational rules you don't enforce — Claude follows them literally.
- Don't let the instruction file rot. A wrong instruction is actively harmful.
- Don't assume `AGENTS.md` is read by Claude Code — it isn't, unless `CLAUDE.md` bridges to it.

---

## 10. Built-in commands — inspect & edit

The native slash commands the CLI handles itself (these *inspect/edit* config; they don't score it):

| Command | Covers | What it does |
|---------|--------|--------------|
| `/doctor` | whole install + config | Diagnoses and verifies the installation and settings, flagging problems (including an overflowing skill-listing budget). |
| `/status` | whole config | Opens the Settings interface on the Status tab — version, model, account, connectivity, loaded settings. |
| `/config` | `settings.json` | Opens the Settings interface to adjust theme, model, output style, and other keys interactively. |
| `/permissions` | `permissions` rules | Opens an interactive dialog to manage allow / ask / deny rules. |
| `/hooks` | `hooks` config | Views hook configurations for tool events. |
| `/mcp` | MCP servers | Manages MCP server connections and OAuth authentication. |
| `/agents` | `.claude/agents/` | Manages subagent configurations (project / user / plugin). |
| `/skills` | `.claude/skills/` | Lists available skills; `Space` to toggle visibility (writes `skillOverrides`), `t` to sort by token count. |
| `/memory` | `CLAUDE.md` / rules / auto-memory | Edits `CLAUDE.md` / `CLAUDE.local.md` / rules files, toggles auto-memory, opens the auto-memory folder. |
| `/init` | `CLAUDE.md` | Generates a starter `CLAUDE.md` (set `CLAUDE_CODE_NEW_INIT=1` for the interactive multi-phase flow). |
| `/plugin` | plugins | Manages Claude Code plugins (browse marketplaces, install/enable/disable). |
| `/model`, `/effort`, `/statusline`, `/terminal-setup` | `settings.json` | Set model / effort / status line / terminal keybindings (persisted to settings). |

See also: [`claude-config-commands.md`](claude-config-commands.md) — every command/skill that
*creates / edits / improves* each entity; [`claude-evaluators.md`](claude-evaluators.md) — everything
that *evaluates / audits / recommends* them; [`claude-config-best-practices.md`](claude-config-best-practices.md)
— per-entity requirements for keeping the harness fast.

---

## Sources

- Overview · Commands — <https://code.claude.com/docs/en/overview> · <https://code.claude.com/docs/en/commands>
- Memory / CLAUDE.md / `.claude/rules/` / `AGENTS.md` bridge — <https://code.claude.com/docs/en/memory>
- Settings (keys, scopes, precedence) — <https://code.claude.com/docs/en/settings>
- Subagents (frontmatter, scopes) — <https://code.claude.com/docs/en/sub-agents>
- Skills (SKILL.md, frontmatter, caps, commands→skills merge) — <https://code.claude.com/docs/en/skills>
- Hooks (events, exit codes, matchers) — <https://code.claude.com/docs/en/hooks>
- MCP — <https://code.claude.com/docs/en/mcp> · Plugins — <https://code.claude.com/docs/en/plugins>
- AGENTS.md open standard — <https://agents.md>
