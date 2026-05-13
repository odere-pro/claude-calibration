[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Settings

`settings.json` — the JSON config substrate: permissions, environment, model, hooks, status line,
auto-update channel, and dozens more keys. Rules here are _enforced by the client_, unlike
`CLAUDE.md`, which is guidance.

## Definition

`settings.json` configures how the Claude Code client behaves: `permissions` (allow / ask / deny
rules), `env`, `model`, `hooks` (see [`hooks.md`](hooks.md)), `statusLine`, `editorMode`,
`autoUpdatesChannel`, `cleanupPeriodDays`, `alwaysThinkingEnabled`, `claudeMdExcludes`,
`skillOverrides`, `availableModels`, `apiKeyHelper`, `disableSkillShellExecution`, and the
technically-enforced ones (`permissions.deny`, `sandbox.enabled`, `forceLoginMethod`,
`forceLoginOrgUUID`) — see the [full key list](https://code.claude.com/docs/en/settings). (A few
client-only things — `autoConnectIde`, `teammateDefaultModel`, … — live in `~/.claude.json`
instead, not `settings.json`.) **Context cost:** zero — settings configure the client, they're not
injected into the model's context — but they shape it indirectly (the `permissions` allowlist drives
how often Claude interrupts you; `model`/`alwaysThinkingEnabled` shape cost; `claudeMdExcludes`/
`skillOverrides` trim what loads). Settings rules are enforced regardless of what Claude decides.

## Scope

[Override-by-name / precedence](../glossary.md) — when a key is set in several scopes, the
higher-precedence value wins; some array keys (e.g. `claudeMdExcludes`) merge across layers.

| Scope   | File                                                                                                                                                                                                                                                                                                                      | Shared with                                  |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| managed | `managed-settings.json` (macOS `/Library/Application Support/ClaudeCode/`, Linux/WSL `/etc/claude-code/`, Windows `C:\Program Files\ClaudeCode\`; also `managed-settings.d/` policy fragments merged alphabetically, Windows Registry `HKLM\SOFTWARE\Policies\ClaudeCode`, macOS prefs domain `com.anthropic.claudecode`) | everyone on the machine; can't be overridden |
| user    | `~/.claude/settings.json` (+ `.local.json`)                                                                                                                                                                                                                                                                               | just you, all projects                       |
| project | `.claude/settings.json`                                                                                                                                                                                                                                                                                                   | the team (committed)                         |
| local   | `.claude/settings.local.json`                                                                                                                                                                                                                                                                                             | just you, this repo (git-ignored)            |
| plugin  | a plugin's root `settings.json` (only the `agent` and `subagentStatusLine` keys are honored; unknown keys silently ignored)                                                                                                                                                                                               | where the plugin is enabled                  |

**Precedence (highest → lowest):** managed → command-line args → local → project → user. Some keys
are restricted by scope: `claudeMd` (embed managed memory) is honored only in managed/policy
settings; `autoMemoryDirectory` only from policy/user settings (not project/local), so a cloned
repo can't redirect auto-memory writes.

## Configure

JSON. Two committed-vs-personal files: `.claude/settings.json` (team) and
`.claude/settings.local.json` (your machine, git-ignored — the right home for per-developer tweaks;
there is no separate per-developer memory file). Claude keeps the 5 most recent timestamped backups.

| Invoke                                          | What it does                                                                                                                                                                                       |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/config` **[built-in]**                        | Opens the Settings interface — change theme, model, output style, and other `settings.json` keys interactively, with the change written back to the appropriate file.                              |
| `/permissions` **[built-in]**                   | Opens an interactive dialog to view and add/edit `permissions` allow / ask / deny rules (rule syntax like `Bash(git *)`, `Edit(*.ts)`, `Skill(commit)`).                                           |
| `/model` **[built-in]**                         | Selects or changes the active model (and, for models that support it, the effort level); the choice is persisted to settings.                                                                      |
| `/effort` **[built-in]**                        | Sets the reasoning-effort level (`low`…`max`, model-dependent); persisted via `effortLevel`.                                                                                                       |
| `/statusline` **[built-in]**                    | Configures the `statusLine` — describe what you want and Claude writes the config, or wire your own script (`~/.claude/statusline-command.sh`).                                                    |
| `/terminal-setup` **[built-in]**                | Configures terminal key bindings (Shift+Enter and other shortcuts); terminal-dependent, only shown when supported.                                                                                 |
| `/keybindings` **[built-in]**                   | Opens or creates `~/.claude/keybindings.json` for customizing in-app keyboard shortcuts.                                                                                                           |
| `/fewer-permission-prompts` **[bundled skill]** | Scans your past transcripts for common read-only Bash/MCP calls and proposes a prioritized allowlist to add to `permissions`, cutting routine approval prompts.                                    |
| `/update-config` **[plugin]**                   | Programmatically edits `settings.json` — adds/moves permissions, sets env vars, wires hooks — for "from now on, when X" automations and permission housekeeping.                                   |
| editing by hand                                 | `cleanupPeriodDays`, `env`, `availableModels`, `editorMode: "vim"` (the `/vim` command was removed in v2.1.92), `claudeMdExcludes`, `skillOverrides`, … — edit the JSON directly or via `/config`. |

## Validate

| Invoke                                 | What it does                                                                                                                                                                                                                                                                   |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/doctor` **[built-in]**               | Diagnoses and verifies the install and settings — auto-updater, settings sanity, native-binary status, IDE/MCP connectivity — and reports problems with status indicators; also flags an overflowing skill-listing budget. Run this first when something behaves unexpectedly. |
| `/status` **[built-in]**               | Opens the Settings interface on the Status tab: version, account/org, active model, working directory, which `settings.json` files are loaded, and connectivity — the "what config is actually active right now" view.                                                         |
| `harness-optimizer` agent **[plugin]** | Analyzes the local harness config — settings, hooks, model routing, subagents — for reliability, cost, and throughput, and proposes concrete changes.                                                                                                                          |
| `claude-code-guide` agent **[plugin]** | Answers whether a given key/value is valid, what it does, and how it should be set.                                                                                                                                                                                            |
| (debug)                                | `/en/debug-your-config` in the docs — the official walkthrough for "why isn't this setting taking effect".                                                                                                                                                                     |

## Improve

**Must**

- No secrets in committed `settings.json`; machine-specific values (and personal tweaks) go in `settings.local.json`, which is git-ignored.
- Never run with `--dangerously-skip-permissions`; build a real `permissions` allowlist instead.
- Know the precedence chain (managed → CLI args → local → project → user) before debugging "why is this setting ignored" — a higher layer is almost always the answer.

**Should**

- Tighten `permissions`: allowlist the safe-and-frequent (let `/fewer-permission-prompts` propose it from your transcripts), but never blanket-allow destructive operations; use rule syntax (`Bash(git *)`, `Edit(*.ts)`) rather than broad allows.
- Keep `env` minimal — only what's genuinely needed every session.
- Don't pin a `model` in committed settings unless the team agrees; otherwise route per task (Haiku = frequent/cheap, Sonnet = main dev, Opus = deep reasoning only). Use `availableModels` to constrain the menu rather than hard-pinning.
- Set a sane `cleanupPeriodDays` so transcript/state growth stays bounded.
- Use `claudeMdExcludes` in a monorepo to skip other teams' ancestor `CLAUDE.md` files; use `skillOverrides` to demote noisy third-party skills to `"name-only"`/`"off"` without editing their files.
- For org-wide enforcement, use _managed_ settings (`permissions.deny`, `sandbox.enabled`, `env`, `forceLoginMethod`) — those are technically enforced; a managed `CLAUDE.md` is only guidance.

| Aspect                                | Recommendation                                                                               | Why                                                                              |
| ------------------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| File format                           | JSON, no comments — keep it small, only the keys you actually set                            | every set key is one more thing to reason about during precedence debugging      |
| Secrets                               | none in committed `settings.json`; `.local.json` for machine-specifics                       | `.local.json` is gitignored; committed files leak                                |
| `permissions`                         | curated allowlist of the safe-and-frequent; rule syntax; nothing destructive blanket-allowed | cuts prompt friction without opening risk; `/fewer-permission-prompts` drafts it |
| `model`                               | don't hard-pin in committed settings; route per task; `availableModels` to constrain         | wrong default = wrong cost on every task                                         |
| `env`                                 | minimal                                                                                      | each var is global to every session                                              |
| `cleanupPeriodDays`                   | tune to bound state growth                                                                   | otherwise transcripts/state grow unbounded                                       |
| `claudeMdExcludes` / `skillOverrides` | use them to trim what loads in monorepos / with noisy skills                                 | both directly reduce context cost                                                |
| Enforcement vs. guidance              | technical rules → managed settings; behavioral → `CLAUDE.md`                                 | settings are enforced by the client; `CLAUDE.md` is not                          |
| Precedence awareness                  | know the 5-layer chain                                                                       | the #1 source of "ignored setting" confusion                                     |

## Sources

- Settings — scopes, precedence, full key list, managed paths, backups — <https://code.claude.com/docs/en/settings>
- Permissions / managed settings — <https://code.claude.com/docs/en/permissions>
- Debug your configuration — <https://code.claude.com/docs/en/debug-your-config>
- Commands (`/config`, `/permissions`, `/model`, `/effort`, `/statusline`, `/terminal-setup`, `/keybindings`, `/fewer-permission-prompts`) — <https://code.claude.com/docs/en/commands>
- Memory (`claudeMd`, `claudeMdExcludes`, `autoMemoryDirectory`) — <https://code.claude.com/docs/en/memory>
