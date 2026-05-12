[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Settings

`settings.json` — the JSON config substrate: permissions, environment, model, hooks, status line,
auto-update channel, and dozens more keys.

## Definition

`settings.json` configures how the Claude Code client behaves: `permissions` (allow / ask / deny
rules), `env`, `model`, `hooks` (see [`hooks.md`](hooks.md)), `statusLine`, `editorMode`,
`autoUpdatesChannel`, `cleanupPeriodDays`, `alwaysThinkingEnabled`, `claudeMdExcludes`,
`skillOverrides`, `availableModels`, `apiKeyHelper`, `permissions.deny`/`sandbox.enabled`/`env`/
`forceLoginMethod` (the technically-enforced ones), and more — see the
[full key list](https://code.claude.com/docs/en/settings). (A few client-only things live in
`~/.claude.json` instead, e.g. `autoConnectIde`.) Settings rules are *enforced by the client*
regardless of what Claude decides — unlike `CLAUDE.md`, which is guidance.

## Scope

[Override-by-name / precedence](../glossary.md) — when a key is set in several scopes, the
higher-precedence value wins (arrays in some keys, e.g. `claudeMdExcludes`, merge).

| Scope | File | Shared with |
|-------|------|-------------|
| managed | `managed-settings.json` (macOS `/Library/Application Support/ClaudeCode/`, Linux/WSL `/etc/claude-code/`, Windows `C:\Program Files\ClaudeCode\`; also `managed-settings.d/` fragments, Windows Registry `HKLM\SOFTWARE\Policies\ClaudeCode`, macOS prefs domain `com.anthropic.claudecode`) | everyone on the machine; can't be overridden |
| user | `~/.claude/settings.json` (+ `.local.json`) | just you, all projects |
| project | `.claude/settings.json` | the team (committed) |
| local | `.claude/settings.local.json` | just you, this repo (git-ignored) |
| plugin | a plugin's root `settings.json` (only `agent`, `subagentStatusLine` keys honored) | where the plugin is enabled |

**Precedence (highest → lowest):** managed → command-line args → local → project → user. Some
keys are restricted: `claudeMd` is honored only in managed/policy settings; `autoMemoryDirectory`
only from policy/user settings (not project/local).

## Configure

JSON. Two committed-vs-personal files: `.claude/settings.json` (team) and
`.claude/settings.local.json` (your machine, git-ignored — the right home for per-developer tweaks;
there is no separate per-developer memory file).

| Invoke | What it does |
|--------|--------------|
| `/config` **[built-in]** | Opens the Settings interface to change theme, model, output style, and other keys interactively. |
| `/permissions` **[built-in]** | Opens an interactive dialog to add/edit allow / ask / deny rules. |
| `/model` **[built-in]** | Selects the model (and effort, where supported); persisted. |
| `/effort` **[built-in]** | Sets the reasoning effort level; persisted via `effortLevel`. |
| `/statusline` **[built-in]** | Configures the `statusLine` — describe what you want, or wire a script (`statusline-command.sh`). |
| `/terminal-setup` **[built-in]** | Configures terminal key bindings (Shift+Enter, …); terminal-dependent. |
| `/keybindings` **[built-in]** | Opens or creates `~/.claude/keybindings.json`. |
| `/fewer-permission-prompts` **[bundled skill]** | Scans your transcripts for safe repeated calls and proposes a tighter `permissions` allowlist. |
| `/update-config` **[plugin]** | Programmatically edits `settings.json` — permissions, env vars, hooks. |
| editing | `editorMode: "vim"` instead of the removed `/vim` command; `cleanupPeriodDays`, `env`, `availableModels`, … by hand or via `/config`. |

## Validate

| Invoke | What it does |
|--------|--------------|
| `/doctor` **[built-in]** | Diagnoses the install and reports broken, invalid, or conflicting settings; also flags an overflowing skill-listing budget. |
| `/status` **[built-in]** | Shows which `settings.json` files are loaded and the resulting active configuration (version, model, account, connectivity). |
| `harness-optimizer` agent **[plugin]** | Reviews settings, hooks, and model routing for reliability, cost, and throughput; proposes concrete changes. |
| `claude-code-guide` agent **[plugin]** | Answers whether a given key/value is valid and how it should be set. |

## Improve

**Must**
- No secrets in committed `settings.json`; machine-specific values go in `settings.local.json` (git-ignored).
- Never run with `--dangerously-skip-permissions`; use a real `permissions` allowlist instead.
- Know the precedence chain (managed → CLI → local → project → user) before debugging "why is this setting ignored".

**Should**
- Tighten `permissions`: allowlist the safe-and-frequent (generate it with `/fewer-permission-prompts`), but never blanket-allow destructive operations.
- Keep `env` minimal.
- Don't pin a `model` in committed settings unless the team agrees; otherwise let task-appropriate routing apply (Haiku = frequent/cheap, Sonnet = main dev, Opus = deep reasoning only).
- Set a sane `cleanupPeriodDays` so transcript/state growth stays bounded.
- For org-wide enforcement, use managed settings (`permissions.deny`, `sandbox.enabled`, `env`, `forceLoginMethod`) rather than `CLAUDE.md` text — settings are enforced, `CLAUDE.md` is not.

| Limit / knob | Value | Note |
|--------------|-------|------|
| Precedence layers | 5 | managed > CLI args > local > project > user |
| `cleanupPeriodDays` | tune to bound state growth | default retention period for session files |
| `claudeMd` / `autoMemoryDirectory` | restricted scopes | `claudeMd` managed-only; `autoMemoryDirectory` policy/user-only |
| Backups | 5 most recent kept | Claude writes timestamped `settings.json.bak*` |

## Sources

- Settings (scopes, precedence, full key list, managed paths) — <https://code.claude.com/docs/en/settings>
- Permissions / managed settings — <https://code.claude.com/docs/en/permissions>
- Commands (`/config`, `/permissions`, `/model`, `/statusline`, `/terminal-setup`, `/fewer-permission-prompts`) — <https://code.claude.com/docs/en/commands>
- Memory (`claudeMd`, `claudeMdExcludes`, `autoMemoryDirectory`) — <https://code.claude.com/docs/en/memory>
