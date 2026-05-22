[← README](README.md) · [Glossary](glossary.md) · [Best practices](claude-config-best-practices.md)

# Claude Code Configuration Structure

Everything Claude Code reads to configure the harness, split into **global** (machine-wide),
**project** (repo-local), **plugin**, and **enterprise** layers. Items marked ✅ exist on the
machine this was captured from; unmarked paths are standard locations Claude looks for. Where a
✅ item is a *custom convention on this machine* rather than a documented Claude Code path, it's
flagged inline.

Captured: 2026-05-13. Validated against <https://code.claude.com/docs/en/overview> and the
sub-pages listed under *Sources* at the bottom.

---

## 1. Global / user level — `~/`

```text
~/
├── .claude.json                    # ✅ Main app state: MCP servers (user + per-project), project list,
│                                   #    conversation history, onboarding flags, oauth, per-project trust
├── .claude.json.backup             # ✅ auto-backup of the above
│
├── CLAUDE.md                       # only picked up if ~/ is an ancestor of your cwd; the designated
│                                   #    user-memory file is ~/.claude/CLAUDE.md (below)
│
└── .claude/                        # ✅ THE config directory
    │
    ├── settings.json               # ✅ Main settings (user scope): permissions, env, model, hooks,
    │                               #    statusLine, autoUpdatesChannel, cleanupPeriodDays, editorMode, …
    ├── settings.local.json          # ✅ Local overrides — git-ignored, machine-specific
    ├── settings.json.bak*           # ✅ rolling backups (Claude keeps the 5 most recent)
    │
    ├── CLAUDE.md                    # user memory — concatenated into every session, all projects
    ├── AGENTS.md                    # ✅ present (ECC bundle) — NOT read by Claude Code; only CLAUDE.md is
    │                                #    a memory file. To use AGENTS.md: `@AGENTS.md` in CLAUDE.md, or symlink.
    │
    ├── rules/                       # ✅ user-level rule files — Claude Code auto-loads ~/.claude/rules/*.md
    │   │                            #    (optionally path-scoped via `paths:` frontmatter); also @-includable.
    │   ├── README.md                #    NOTE: in this setup the files are pulled in via @-includes from
    │   ├── common/                  #    ~/.claude/CLAUDE.md rather than relying on auto-load.
    │   │                            #    common/: coding-style, git-workflow, testing, performance, patterns,
    │   │                            #    hooks, agents, security, code-review, development-workflow
    │   ├── typescript/  python/  golang/  rust/  java/  kotlin/  swift/  php/
    │   ├── cpp/  csharp/  dart/  perl/    # each: coding-style, hooks, patterns, security, testing
    │   ├── web/                      #    coding-style, design-quality, hooks, patterns, performance, security, testing
    │   └── zh/                       #    Chinese translations of common/
    │
    ├── agents/                       # ✅ user subagent definitions (one *.md per agent: YAML frontmatter + body=system prompt)
    │   ├── code-reviewer.md  planner.md  architect.md  tdd-guide.md  security-reviewer.md
    │   ├── harness-optimizer.md  conversation-analyzer.md  build-error-resolver.md
    │   └── … language reviewers, build resolvers, gan-*, opensource-*, etc.  (these come from plugins/setup,
    │                                  #    not from Claude Code itself; Claude Code's built-ins are Explore/Plan/general-purpose)
    │
    ├── commands/                     # ✅ user slash commands (one *.md per command). NOTE: custom commands have
    │                                 #    been merged into skills — `.claude/skills/<name>/SKILL.md` is the new form;
    │                                 #    `commands/*.md` still works for back-compat. (skill > command on name clash)
    │
    ├── skills/                       # ✅ user skills — one directory per skill, each with SKILL.md (+ scripts/refs)
    │   ├── api-design/  backend-patterns/  coding-standards/  database-migrations/
    │   ├── dmux-workflows/  frontend-design/  frontend-patterns/  frontend-slides/
    │   └── postgres-patterns/
    ├── skills-disabled/              # ✅ custom convention on this machine — Claude Code's own way to hide skills is
    │                                 #    the `skillOverrides` setting + `disable-model-invocation`/`user-invocable` frontmatter
    │
    ├── hooks/                        # ✅ user hook scripts + hooks.json. Hook *entries* normally live under the
    │   ├── hooks.json                #    `hooks` key in a settings.json; plugins use `hooks/hooks.json`.
    │   └── README.md
    │
    ├── mcp-configs/                  # ✅ custom on this machine — the documented MCP config locations are ~/.claude.json,
    │   └── mcp-servers.json          #    project .mcp.json, plugin .mcp.json, and enterprise managed-mcp.json
    │
    ├── plugins/                      # ✅ Plugin system
    │   ├── installed_plugins.json    #    which plugins are enabled (+ .bak files)
    │   ├── known_marketplaces.json   #    registered marketplaces
    │   ├── blocklist.json
    │   ├── install-counts-cache.json
    │   ├── marketplaces/             #    cloned marketplace repos:
    │   │   ├── anthropic-agent-skills/
    │   │   ├── claude-code-plugins/
    │   │   └── claude-plugins-official/   # each plugin: .claude-plugin/plugin.json + agents/ commands/ skills/ hooks/ .mcp.json …
    │   ├── cache/                    #    installed plugin payloads
    │   └── data/
    ├── marketplace.json              # ✅ (custom on this machine)
    ├── plugin.json                   # ✅ (custom on this machine — treats ~/.claude itself as a plugin)
    ├── PLUGIN_SCHEMA_NOTES.md        # ✅ (custom)
    │
    ├── .agents/                      # ✅ custom — secondary agents/skills tree ("everything-claude-code" bundle)
    │   ├── plugins/marketplace.json
    │   └── skills/ … (agent-introspection-debugging, deep-research, eval-harness, …)
    ├── ecc/                          # ✅ custom — ECC bundle support files
    │
    ├── statusline-command.sh         # ✅ script that renders the status line (wired via settings.statusLine)
    ├── README.md                     # ✅
    ├── keybindings.json              # (optional) custom key bindings — created via /keybindings
    │
    └── ── runtime / state (Claude writes & reads these; not "config" you hand-edit) ──
        ├── projects/                 # ✅ per-project conversation transcripts (*.jsonl) + memory/
        │   └── -Users-…-<project>/
        │       ├── <session>.jsonl
        │       ├── memory/           #    ← auto-memory store: MEMORY.md index (first 200 lines / 25 KB loaded) + topic *.md
        │       └── …/tool-results/
        ├── sessions/                 # ✅ session metadata / aliases
        ├── session-env/              # ✅ per-session environment snapshots
        ├── shell-snapshots/          # ✅ captured shell init state
        ├── history.jsonl             # ✅ prompt history
        ├── file-history/             # ✅ edit/undo history per session
        ├── tasks/  scheduled-tasks/  # ✅ background tasks + routines (/tasks, /schedule)
        ├── telemetry/  usage-data/  stats-cache.json    # ✅ usage stats
        ├── cache/  paste-cache/  downloads/  debug/  ide/    # ✅ misc runtime
        ├── backups/                  # ✅ config backups
        ├── plans/                    # ✅ saved plan-mode docs
        └── scripts/                  # ✅ helper scripts
```

---

## 2. Project level — inside the repo

Claude resolves project config relative to the working directory and walks **up** the directory
tree for memory files. None of these need to exist; create the ones you want.

```text
<project-root>/
├── CLAUDE.md                        # project memory — committed, shared (or ./.claude/CLAUDE.md instead)
├── CLAUDE.local.md                  # personal project memory — add to .gitignore (for worktrees, import from ~/ instead)
├── AGENTS.md                        # open-standard file — Claude Code reads it only if CLAUDE.md does `@AGENTS.md` (or is a symlink to it)
├── .mcp.json                        # project-scoped MCP servers — committed
└── .claude/
    ├── CLAUDE.md                    # alternative location for project memory
    ├── settings.json                # project settings: permissions, env, hooks — committed
    ├── settings.local.json          # personal project settings — git-ignored
    ├── rules/                       # auto-loaded rule files (*.md); optional `paths:` frontmatter scopes them to globs
    │   └── *.md                     #     supports symlinks; loaded at launch (or when matching files open)
    ├── agents/                      # project-scoped subagents (highest-priority non-managed scope)
    ├── commands/                    # project-scoped slash commands (legacy form; prefer skills/)
    ├── skills/                      # project-scoped skills — <name>/SKILL.md (+ supporting files)
    └── hooks/                       # project-scoped hook scripts (entries go under `hooks` in settings.json)
```

---

## 3. Plugins

A plugin is a directory with a `.claude-plugin/plugin.json` manifest plus any of these at the
plugin root (NOT inside `.claude-plugin/`):

```text
<plugin>/
├── .claude-plugin/plugin.json       # manifest: name (= skill namespace), description, version, author, …
├── skills/        # <name>/SKILL.md  — adds skills (invoked as  /plugin-name:skill-name)
├── commands/      # flat *.md         — legacy skill form; "use skills/ for new plugins"
├── agents/        # *.md              — adds subagents (plugin agents ignore hooks/mcpServers/permissionMode)
├── hooks/hooks.json                  # adds hooks
├── .mcp.json                         # adds MCP servers
├── .lsp.json                         # adds LSP servers (code intelligence)
├── monitors/monitors.json            # adds background monitors
├── bin/                              # executables added to the Bash PATH while enabled
└── settings.json                     # default settings applied when enabled (only `agent`, `subagentStatusLine`)
```

On disk here: `~/.claude/plugins/cache/<marketplace>/<plugin>/...` (installed payloads) and
`~/.claude/plugins/marketplaces/<marketplace>/...` (cloned marketplace repos). Enabled plugins
are tracked in `~/.claude/plugins/installed_plugins.json`. Active marketplaces here:
`anthropic-agent-skills`, `claude-code-plugins`, `claude-plugins-official`.

---

## 4. Enterprise / managed (admin-enforced — not present on this machine)

Highest precedence; cannot be overridden by users. Same system directory holds several files:

```text
macOS    /Library/Application Support/ClaudeCode/managed-settings.json   (+ managed-settings.d/, CLAUDE.md, managed-mcp.json, agents/, skills/)
Linux/WSL /etc/claude-code/managed-settings.json                          (+ same siblings)
Windows  C:\Program Files\ClaudeCode\managed-settings.json                (+ same siblings)
         also: Windows Registry HKLM\SOFTWARE\Policies\ClaudeCode; macOS managed prefs domain com.anthropic.claudecode
```

Managed `settings.json` can also embed memory directly via the `claudeMd` key (honored only in
managed/policy settings).

---

## Precedence & load order

### `settings.json` resolution (highest → lowest)

1. **Managed** (enterprise / policy `managed-settings.json`) — cannot be overridden
2. **Command-line arguments** — temporary session overrides
3. **Local** — `.claude/settings.local.json`
4. **Project** — `.claude/settings.json`
5. **User** — `~/.claude/settings.json`

### Memory (`CLAUDE.md` + `.claude/rules/`) load order

1. **Managed policy** `CLAUDE.md` (or `claudeMd` key in `managed-settings.json`) — loads before everything
2. **User** `~/.claude/CLAUDE.md` and `~/.claude/rules/*.md`
3. **Project** `CLAUDE.md` / `CLAUDE.local.md` — discovered by walking **up** the directory tree from
   cwd. All discovered files are *concatenated* (not "overridden"): ordered filesystem-root → cwd, so
   the file closest to where you launched Claude is read **last**; within a directory, `CLAUDE.local.md`
   is appended after `CLAUDE.md`. `.claude/rules/*.md` load at the same priority as `.claude/CLAUDE.md`.
4. **Subdirectory** `CLAUDE.md` / `CLAUDE.local.md` *below* cwd load on demand when Claude reads files there.

`AGENTS.md` is **not** read directly by Claude Code — it only enters context if `CLAUDE.md` imports
it (`@AGENTS.md`) or is a symlink to it. `@path` imports expand into context at launch (relative paths
resolve against the importing file; recursive imports allowed, max depth 5 hops). Block-level HTML
comments in `CLAUDE.md` are stripped before injection. Use `claudeMdExcludes` to skip ancestor files
in monorepos.

### Discovery rules of thumb

- **Skills**: union of `~/.claude/skills/`, project `.claude/skills/`, `.claude/skills/` inside any
  `--add-dir` directory, and every enabled plugin's `skills/`. Name clash: enterprise > personal >
  project; plugin skills are namespaced `plugin-name:skill-name`. Visibility is tuned with the
  `skillOverrides` setting and the `disable-model-invocation` / `user-invocable` frontmatter.
- **Subagents**: managed > `--agents` flag > project `.claude/agents/` > user `~/.claude/agents/` >
  plugin `agents/`. Not loaded from `--add-dir` directories. Built-in agents: `Explore`, `Plan`,
  `general-purpose`.
- **Slash commands / skills**: a `.claude/commands/foo.md` and a `.claude/skills/foo/SKILL.md` both
  create `/foo`; the skill wins on a clash. Plugin commands/skills are namespaced `plugin:foo`.
  Not loaded from `--add-dir` directories.
- **Hooks**: merged from every `settings.json` in the precedence chain, plus plugin `hooks/hooks.json`,
  plus skill/agent frontmatter `hooks`.
- **MCP servers**: merged from `~/.claude.json` (user + per-project local sections), project `.mcp.json`,
  plugin `.mcp.json`, and enterprise `managed-mcp.json`. Subagents can also define their own via the
  `mcpServers` frontmatter field.

---

## Sources

- Overview — <https://code.claude.com/docs/en/overview>
- Settings (scopes, precedence, key list, managed paths) — <https://code.claude.com/docs/en/settings>
- Memory / CLAUDE.md / `.claude/rules/` / imports / load order — <https://code.claude.com/docs/en/memory>
- Subagents (scopes, frontmatter, precedence) — <https://code.claude.com/docs/en/sub-agents>
- Skills (SKILL.md, frontmatter, commands→skills merge, scopes) — <https://code.claude.com/docs/en/skills>
- Hooks (events, config locations) — <https://code.claude.com/docs/en/hooks>
- MCP — <https://code.claude.com/docs/en/mcp>
- Plugins / plugins reference — <https://code.claude.com/docs/en/plugins> · <https://code.claude.com/docs/en/plugins-reference>
- Commands reference — <https://code.claude.com/docs/en/commands>
