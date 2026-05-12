# Claude Code ↔ `AGENTS.md` Open Standard — Feature Mapping

> Open standard: <https://agents.md> · Claude config layout: see `claude-structure.md`

**The one thing to know:** Claude Code reads `CLAUDE.md`, **not** `AGENTS.md`
([memory docs](https://code.claude.com/docs/en/memory#agents-md)). You bridge the gap once —
either import the open-standard file from `CLAUDE.md` (`@AGENTS.md`) or symlink
(`ln -s AGENTS.md CLAUDE.md`). After that bridge is in place, behavior is effectively identical,
and anything you author against the open standard is honored by Claude Code.

---

## 1. Bridge recipes

```bash
# Project: make CLAUDE.md a symlink to AGENTS.md (single source of truth; no Claude-specific content)
cd <repo> && ln -s AGENTS.md CLAUDE.md

# Monorepo: do it per package
for d in apps/* packages/*; do (cd "$d" && [ -f AGENTS.md ] && ln -sf AGENTS.md CLAUDE.md); done

# If you also need Claude-specific instructions, use an import instead of a symlink:
#   CLAUDE.md:
#     @AGENTS.md
#
#     ## Claude Code
#     Use plan mode for changes under src/billing/.
```

On Windows, symlinks need Administrator privileges or Developer Mode — use the `@AGENTS.md`
import there. For *other* tools (Codex, Cursor, …) that read `AGENTS.md` directly, no bridge is
needed; the symlink/import is only because Claude Code looks for `CLAUDE.md`.

Tip: make the **open-standard file (`AGENTS.md`) the real file** and `CLAUDE.md` the symlink, so
the portable artifact is the source of truth.

---

## 2. Once bridged — behavioral equivalence

| Behavior | Open standard (`AGENTS.md`) | Claude Code (via `CLAUDE.md` ⟵ `@AGENTS.md` / symlink) | Same? |
|----------|------------------------------|---------------------------------------------------------|-------|
| Native read | Agents read `AGENTS.md` at the repo root directly | Reads `CLAUDE.md`; the bridge makes `AGENTS.md` content arrive at session start | ⚠️ needs the one-line bridge |
| Discovery | Agent reads the file at the repo root | `CLAUDE.md` files loaded at session start | ✅ |
| Nesting / monorepo | Nearest `AGENTS.md` to the edited file wins; parent applies otherwise | Walks **up** the dir tree from cwd; all `CLAUDE.md`/`CLAUDE.local.md` found are concatenated (root → cwd, so closer is read last); subdirectory files load on demand when Claude reads files there | ✅ |
| Multiple levels combine | Root + nested both inform the agent | All discovered files concatenated into context | ✅ |
| Explicit prompt vs. file | A direct chat prompt overrides the file | A chat instruction overrides the memory file | ✅ |
| "Run the checks" | Programmatic steps are expected to actually run | Claude runs the commands, doesn't just acknowledge them | ✅ |
| Plain Markdown, no schema | Any headings; nothing mandatory | Same — free-form Markdown | ✅ |
| Includes / references | Some tools support `@path` imports | `@path` imports work in `CLAUDE.md` (and anything it imports, e.g. `@AGENTS.md`, `~/.claude/rules/**`); max depth 5 hops | ✅ |
| Path-scoped rules | Not part of the standard | Extra: `.claude/rules/*.md` with `paths:` frontmatter load only for matching files | ➕ Claude-only bonus |

---

## 3. What has no open-standard counterpart (Claude-only)

`AGENTS.md` is scoped to *instructions*. These Claude Code entities have no `agents.md` equivalent
and live under `.claude/` (see `claude-project-configuration.md`): `settings.json`
(permissions/env/model/hooks), hooks, subagents, slash commands / skills, plugins, MCP-server
config (`.mcp.json` — MCP itself is an open protocol, but the config file is per-tool),
keybindings, status line. Keep `AGENTS.md` for the portable "how this repo works"; accept the
rest is Claude-specific.

---

## Sources

- AGENTS.md open standard — <https://agents.md>
- Claude Code memory / `AGENTS.md` bridging / `@path` imports / `.claude/rules/` —
  <https://code.claude.com/docs/en/memory>
- Companion docs in this repo: `agents-md-structure.md`, `claude-project-configuration.md`,
  `claude-structure.md`.
