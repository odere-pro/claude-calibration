[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Hooks

Shell commands, HTTP requests, prompts, or subagents that fire on lifecycle events — the
deterministic way to make something happen every time, regardless of what Claude decides.

## Definition

A hook = an **event** (e.g. `PreToolUse`, `Stop`) + a **matcher** (which occurrences fire it) +
one or more **handlers** (`type: command` shell command, or HTTP / MCP-tool / prompt / agent). The
trigger is guaranteed; outcome can vary only for prompt/agent handlers. Put guardrails here — an
instruction like "never edit `.env`" in `CLAUDE.md` is a request; a `PreToolUse` hook that blocks
the edit is enforcement. **Context cost:** zero unless the hook returns output (a `PostToolUse`
linter, for example, feeds its results back as text Claude reads). Hooks run **synchronously** and
many can block or delay the tool call.

## Scope

[Additive](../glossary.md) — all registered hooks fire for their matching events regardless of
source; nothing is suppressed.

| Scope | Location | Shared with |
|-------|----------|-------------|
| user | `~/.claude/settings.json` → `hooks` | just you, all projects |
| project | `.claude/settings.json` → `hooks` | the team (committed) |
| local | `.claude/settings.local.json` → `hooks` | just you, this repo (git-ignored) |
| managed | managed-policy settings → `hooks` | everyone in the org |
| plugin | a plugin's `hooks/hooks.json` | where the plugin is enabled |
| skill / subagent | the `hooks` frontmatter field | while that component is active |

(Hook *scripts* can live anywhere — commonly `.claude/hooks/`; reference them with
`${CLAUDE_PROJECT_DIR}/.claude/hooks/...`. Not loaded from `--add-dir` directories.)

## Configure

Three levels of nesting: event → matcher group → handlers.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "if": "Bash(rm *)", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh" }
        ]
      }
    ],
    "PostToolUse": [
      { "matcher": "Write|Edit", "hooks": [ { "type": "command", "command": "jq -r '.tool_input.file_path' | xargs npm run lint:fix" } ] }
    ]
  }
}
```

**Events** (selected): tool events `PreToolUse`, `PostToolUse`, `PostToolUseFailure`,
`PostToolBatch`, `PermissionRequest`, `PermissionDenied`; turn events `UserPromptSubmit`,
`UserPromptExpansion`, `Stop`, `StopFailure`; session events `SessionStart`, `SessionEnd`, `Setup`,
`InstructionsLoaded`; agent/team events `SubagentStart`, `SubagentStop`, …; plus `ConfigChange`,
`FileChanged`, `PreCompact`/`PostCompact`, `Notification`, and more — see the full list in the
[hooks reference](https://code.claude.com/docs/en/hooks).

**Matcher**: `*` / `""` / omitted = match all; only letters/digits/`_`/`|` = exact name or
`|`-separated list (`Edit|Write`); anything else = a JavaScript regex (`^Notebook`, `mcp__memory__.*`,
`mcp__.*__write.*`). What it matches depends on the event (tool name, session-start reason,
notification type, agent type, …; some events take no matcher). The optional `if` field adds
permission-rule-syntax filtering on *tool* events: `"Bash(git *)"`, `"Edit(*.ts)"`.

**Exit codes**: **0** = success (stdout parsed for JSON output fields — only on exit 0); **2** =
blocking error (stdout ignored; stderr fed back to Claude); **any other code** = non-blocking error.
Only `exit 2` blocks — `exit 1` is treated as non-blocking; for enforcement, `exit 2` or emit a
JSON `permissionDecision`. What `exit 2` does is per-event: `PreToolUse` → blocks the tool;
`PermissionRequest` → denies; `UserPromptSubmit` → blocks & erases the prompt; `Stop` → keeps Claude
going; `PostToolUse` → just shows stderr (the tool already ran).

| Invoke | What it does |
|--------|--------------|
| editing | Add a `hooks` block to a `settings.json` (or `hooks/hooks.json` in a plugin), or `hooks` frontmatter in a skill/subagent. |
| `/init` **[built-in]** | The interactive flow (`CLAUDE_CODE_NEW_INIT=1`) can scaffold hooks alongside `CLAUDE.md`. |
| `/update-config` **[plugin]** | Writes hook definitions into `settings.json`. |

## Validate

| Invoke | What it does |
|--------|--------------|
| `/hooks` **[built-in]** | Views the configured hooks and the events that fire them. |
| `conversation-analyzer` agent **[plugin]** | Reads transcripts to surface repeated behaviors worth enforcing with a *new* hook. |
| `harness-optimizer` agent **[plugin]** | Judges whether the hooks you already have are well-configured and correctly ordered. |
| `InstructionsLoaded` hook **[built-in]** | (Itself a hook) logs which instruction files loaded — useful when debugging config + hook interplay. |

## Improve

**Must**
- Keep hooks fast — sub-second where possible. Heavy work belongs on `Stop`, not `PreToolUse`/`PostToolUse` (they block / delay the tool call).
- Use project-owned tooling (`pnpm prettier`, repo scripts), never remote one-off execution of untrusted code.
- For enforcement, use **exit code `2`** (or a JSON `permissionDecision`) — `exit 1` is non-blocking.

**Should**
- Scope `matcher` narrowly (`Edit|Write`, not bare `*` on hot paths); use the `if` field for finer tool/argument filtering.
- Order cheapest/most-local first: format → lint → type-check → build; reserve full build for `Stop`.
- Keep hooks idempotent and side-effect-safe.
- Add hooks in response to observed, repeated pain (the `conversation-analyzer` agent finds these) — don't over-hook.
- If a rule must hold every time, make it a hook, not a `CLAUDE.md`/skill instruction.

| Limit / knob | Value | Note |
|--------------|-------|------|
| `PreToolUse` / `PostToolUse` runtime | < 1 s (a few seconds ceiling) | blocks / delays the tool call |
| `Stop` / build hook runtime | < ~30–60 s | where slow work goes |
| Hook count | single digits | each runs on every matching event |
| Exit codes | `0` = ok (JSON on stdout); `2` = block (stderr → Claude); other = non-blocking | only `2` blocks |
| Context cost | zero | unless the hook returns output, which becomes a message Claude reads |

## Sources

- Hooks reference (events, matchers, exit codes, JSON output) — <https://code.claude.com/docs/en/hooks>
- Automate workflows with hooks (guide) — <https://code.claude.com/docs/en/hooks-guide>
- Extend Claude Code (Hook vs Skill; context cost) — <https://code.claude.com/docs/en/features-overview>
- Commands (`/hooks`) — <https://code.claude.com/docs/en/commands>
