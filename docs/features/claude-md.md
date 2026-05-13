[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# CLAUDE.md

Plain-Markdown instruction files Claude loads into context at the start of every session.

## Definition

`CLAUDE.md` (plus `CLAUDE.local.md`, and the `.claude/rules/*.md` files covered in
[`rules.md`](rules.md)) holds persistent project/personal/org instructions: build & test commands,
coding conventions, project layout, "always do X" rules. It's delivered as a user message _after_
the system prompt — so it's _context_, not enforced configuration; how specific and concise it is
determines how reliably Claude follows it. **Context cost:** the full content of every in-scope file
loads into context on every request — this is the most direct, constant drain you control. Distinct
from **auto memory** (notes Claude writes itself, [below](#auto-memory)). `AGENTS.md` is _not_ read
directly by Claude Code — see [importing `AGENTS.md`](#importing-agentsmd).

## Scope

[Additive](../glossary.md): all in-scope files are concatenated into context (closer = read last),
not overridden.

| Scope   | Location                                                                                                                                                                                                | Shared with                                         |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| managed | macOS `/Library/Application Support/ClaudeCode/CLAUDE.md` · Linux/WSL `/etc/claude-code/CLAUDE.md` · Windows `C:\Program Files\ClaudeCode\CLAUDE.md` (or the `claudeMd` key in `managed-settings.json`) | everyone on the machine; can't be excluded by users |
| user    | `~/.claude/CLAUDE.md`                                                                                                                                                                                   | just you, all projects                              |
| project | `./CLAUDE.md` or `./.claude/CLAUDE.md`                                                                                                                                                                  | the team (committed)                                |
| local   | `./CLAUDE.local.md` (add to `.gitignore`; for git worktrees, `@`-import a file from `~/` instead, since a gitignored file only exists in the worktree where you made it)                                | just you, this repo                                 |

**Load order:** managed → user (`~/.claude/CLAUDE.md` + `~/.claude/rules/*`) → project files found
by walking **up** the tree from cwd (ordered filesystem-root → cwd, so the closest file is read
**last**; `CLAUDE.local.md` is appended after `CLAUDE.md` at each level; `.claude/rules/*` load at
the priority of `.claude/CLAUDE.md`). Subdirectory `CLAUDE.md` files _below_ cwd load on demand when
Claude reads files there — and they are _not_ re-injected after `/compact` until then (the
project-root `CLAUDE.md` is). Use `claudeMdExcludes` (a glob list, in `.claude/settings.local.json`
or any settings layer; arrays merge across layers) to skip irrelevant ancestor files in a monorepo;
a managed `CLAUDE.md` cannot be excluded.

## Configure

Plain Markdown — any headings, no schema, no frontmatter. Block-level HTML comments (`<!-- … -->`)
are stripped before injection, so use them for human-only maintainer notes at zero token cost
(comments inside code blocks are kept; comments are visible if you open the file with the Read
tool). `@path` imports expand into context at launch: both relative and absolute paths work
(relative resolves against the _importing_ file, not cwd); imports can recursively import, **max
depth 5 hops**; the first external import in a project triggers a one-time approval dialog (decline
once and imports stay disabled). Imports load at launch too — they organize, they don't shrink
context; for that, push content into path-scoped [`.claude/rules/`](rules.md) instead.

| Invoke                                                  | What it does                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/init` **[built-in]**                                  | Scans the codebase with a subagent and generates a starter `CLAUDE.md` with the build/test commands and conventions it discovers. If a `CLAUDE.md` already exists it _suggests improvements_ rather than overwriting. Set `CLAUDE_CODE_NEW_INIT=1` for the interactive multi-phase flow (it asks which artifacts to set up — CLAUDE.md, skills, hooks — and presents a reviewable proposal). Reads an existing `AGENTS.md` / `.cursorrules` / `.windsurfrules` and folds the relevant parts in. |
| `/memory` **[built-in]**                                | Lists every `CLAUDE.md` / `CLAUDE.local.md` / rules file loaded this session and opens any of them in your editor; also toggles auto memory on/off and gives a link to open the auto-memory folder.                                                                                                                                                                                                                                                                                             |
| `#<text>` (prompt prefix) **[built-in]**                | "Remember this." Claude saves the note to **auto memory** (`~/.claude/projects/<project>/memory/`), _not_ to `CLAUDE.md`. To put something in `CLAUDE.md` instead, ask Claude "add this to CLAUDE.md" or edit the file yourself via `/memory`.                                                                                                                                                                                                                                                  |
| `/claude-md-management:revise-claude-md` **[plugin]**   | Reviews the current session for things worth persisting and updates `CLAUDE.md` with them (e.g. a correction you typed, a command Claude got wrong).                                                                                                                                                                                                                                                                                                                                            |
| `/claude-md-management:claude-md-improver` **[plugin]** | Scans every `CLAUDE.md`/`AGENTS.md` in the repo, scores it against best-practice templates (length, structure, specificity, conflicts), reports the gaps, and applies targeted fixes.                                                                                                                                                                                                                                                                                                           |
| `--append-system-prompt "<text>"` (CLI)                 | Injects text at the _system-prompt_ level instead of as memory — stronger adherence, but must be passed on every invocation, so it suits scripts/automation more than interactive use.                                                                                                                                                                                                                                                                                                          |

### Importing `AGENTS.md`

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. To use the open-standard file, import it:

```markdown
@AGENTS.md

## Claude Code

Claude-specific instructions can go here, below the import.
```

…or `ln -s AGENTS.md CLAUDE.md` if you don't need Claude-specific additions (on Windows a symlink
needs Administrator / Developer Mode — use the `@AGENTS.md` import there). See
[`reference/agents-md.md`](../reference/agents-md.md).

### Auto memory

Claude writes its own notes across sessions under `~/.claude/projects/<project>/memory/` — a
`MEMORY.md` index plus topic files (`debugging.md`, `api-conventions.md`, …). The path is derived
from the git repo, so all worktrees/subdirs of one repo share it. Only the first **200 lines /
25 KB** of `MEMORY.md` loads at session start; topic files load on demand. On by default (needs
v2.1.59+); toggle via `/memory`, `autoMemoryEnabled` in settings, or `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`;
relocate with `autoMemoryDirectory` (policy/user settings only — not project/local, so a cloned
repo can't redirect writes). Files are plain Markdown you can read, edit, or delete.

## Validate

| Invoke                                                  | What it does                                                                                                                                                                                                                                                        |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/memory` **[built-in]**                                | Confirms exactly which `CLAUDE.md` / `CLAUDE.local.md` / rules files are loaded this session — if a file isn't in the list, Claude can't see it (wrong location, excluded, or lazy-loaded subtree). The fastest "why isn't Claude following my instructions" check. |
| `InstructionsLoaded` hook **[built-in]**                | A hook that fires when instruction files load; use it to log exactly which files loaded, when, and why — the way to debug path-scoped rules or lazy-loaded subdirectory `CLAUDE.md` files.                                                                          |
| `/doctor` **[built-in]**                                | General config/install health check; among other things flags an overflowing skill-listing budget that can crowd out skill descriptions (related, since both compete for context).                                                                                  |
| `/claude-md-management:claude-md-improver` **[plugin]** | Scores `CLAUDE.md`/`AGENTS.md` against best-practice templates (length, structure, specificity, internal conflicts) and reports the issues before fixing them.                                                                                                      |
| `harness-optimizer` agent **[plugin]**                  | Reviews `CLAUDE.md` as part of a whole-harness audit — flags bloat, vague rules, and content that should be a hook or a path-scoped rule instead.                                                                                                                   |

If Claude isn't following `CLAUDE.md`: verify `/memory` lists it; make instructions more specific
("Use 2-space indentation" beats "format code properly"); look for conflicting instructions across
nested files; if it must run at a fixed point (before every commit, after each edit), make it a
[hook](hooks.md) — `CLAUDE.md` is a request, a hook is enforcement.

## Improve

**Must**

- No secrets, tokens, or internal URLs — it's committed. Point at `.env.example` or a secret manager.
- Only write instructions you'd actually enforce — Claude follows the file literally, so aspirational rules are pure noise (and context). For something that _must_ happen at a fixed point, use a hook, not a `CLAUDE.md` line.
- Keep nested files non-contradictory — discovered files are _concatenated_ (closer read last), not "closest wins", so don't restate a rule at multiple levels; only state how a level _differs_.

**Should**

- Keep it **under ~200 lines** per `CLAUDE.md` file. Longer files consume more context and measurably reduce adherence; the moment it's growing, move content to `.claude/rules/` or imports.
- Move bulky or path-specific content into [`.claude/rules/`](rules.md) — path-scoped rules load only when Claude touches matching files, so they cost zero context the rest of the time; `@path` imports help _organization_ but still load at launch.
- Front-load the most load-bearing rules; use Markdown `##` headers and bullets to group by topic (Claude scans structure the way readers do); put exact commands in backticks so they're run verbatim.
- Be concrete and verifiable: "Run `npm test` before committing" beats "test your changes"; "API handlers live in `src/api/handlers/`" beats "keep files organized".
- Import `AGENTS.md` from `CLAUDE.md` (`@AGENTS.md` or a symlink) rather than maintaining two files; make `AGENTS.md` the real file.
- Use block-level HTML comments for maintainer notes — they're stripped before injection (free).
- Update it in the same PR as the workflow change it describes; periodically re-read it (and nested files, and `.claude/rules/`) to delete outdated/conflicting lines; prune `claudeMdExcludes` in monorepos.
- Keep `MEMORY.md` (auto memory) lean too — only its first 200 lines / 25 KB load; let Claude move detail into topic files; edit/delete stale entries.
- Don't restate the README — link to it.

| Aspect                                    | Recommendation                                                            | Why                                                                                  |
| ----------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `CLAUDE.md` length                        | target < ~200 lines / a screen or two per file                            | loaded in full every request; long files dilute attention and reduce adherence       |
| Overflow strategy                         | move to `.claude/rules/` (path-scoped) > `@path` imports                  | rules can be conditional; imports still load at launch                               |
| `@path` import depth                      | ≤ 5 hops; relative paths resolve against the importing file               | hard limit; deeper chains are hard to reason about                                   |
| Structure                                 | one `#` title → `##` topic sections → bullets; most important rules first | scannable for the model; emphatic wording (`MUST`/`NEVER`) is weighted more          |
| Specificity                               | concrete, verifiable instructions only                                    | vague rules don't change behavior and still cost context                             |
| HTML comments                             | use `<!-- … -->` (block-level) for human-only notes                       | stripped before injection — zero token cost                                          |
| Per-developer overrides                   | `CLAUDE.local.md` (gitignored) or `@~/...` import                         | keeps personal prefs out of the committed file; the import survives across worktrees |
| `MEMORY.md` (auto memory) loaded at start | first 200 lines / 25 KB                                                   | beyond that lives in topic files loaded on demand                                    |
| Maintenance cadence                       | review on every workflow change; periodic conflict sweep                  | concatenated files drift; a wrong instruction is actively harmful                    |

## Sources

- Memory — CLAUDE.md, load order, `@path` imports, `.claude/rules/`, auto memory, `AGENTS.md` — <https://code.claude.com/docs/en/memory>
- Best practices — "write an effective CLAUDE.md" — <https://code.claude.com/docs/en/best-practices>
- Extend Claude Code — CLAUDE.md vs Skills vs Rules; context cost by feature — <https://code.claude.com/docs/en/features-overview>
- Commands (`/init`, `/memory`) — <https://code.claude.com/docs/en/commands> · Hooks (`InstructionsLoaded`) — <https://code.claude.com/docs/en/hooks>
