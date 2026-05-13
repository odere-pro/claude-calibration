[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Hooks

Shell commands, HTTP requests, prompts, or subagents that fire on lifecycle events — the
deterministic way to make something happen _every time_, regardless of what Claude decides.

## Definition

A hook = an **event** (e.g. `PreToolUse`, `Stop`, `SessionStart`) + a **matcher** (which occurrences
of that event it fires on) + one or more **handlers** (`type: command` shell command, `http`, `mcp`
tool, `prompt`, or `agent`). The trigger is guaranteed — that's the point: an instruction like
"never edit `.env`" in `CLAUDE.md` or a skill is a _request_; a `PreToolUse` hook that blocks the
edit is _enforcement_. Hooks run **synchronously**, and many (`PreToolUse`, `PermissionRequest`,
`UserPromptSubmit`, `Stop`, …) can block or delay the action. **Context cost: zero by default** —
hooks execute outside the conversation; the only time a hook touches context is when it _returns
output_ (a `PostToolUse` linter, for example, feeds its results back as text Claude reads).

## Scope

[Additive](../glossary.md) — all registered hooks fire for their matching events regardless of
source; nothing is suppressed.

| Scope            | Location                                | Shared with                       |
| ---------------- | --------------------------------------- | --------------------------------- |
| user             | `~/.claude/settings.json` → `hooks`     | just you, all projects            |
| project          | `.claude/settings.json` → `hooks`       | the team (committed)              |
| local            | `.claude/settings.local.json` → `hooks` | just you, this repo (git-ignored) |
| managed          | managed-policy settings → `hooks`       | everyone in the org               |
| plugin           | a plugin's `hooks/hooks.json`           | where the plugin is enabled       |
| skill / subagent | the `hooks` frontmatter field           | while that component is active    |

Hook _scripts_ can live anywhere — commonly `.claude/hooks/`; reference them with
`${CLAUDE_PROJECT_DIR}/.claude/hooks/...`. Not loaded from `--add-dir` directories. The command
receives the hook input as JSON on stdin (use `jq` to pull fields, e.g. `jq -r '.tool_input.file_path'`).

## Configure

Three levels of nesting: **event → matcher group → handlers**.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(rm *)",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npm run lint:fix"
          }
        ]
      }
    ]
  }
}
```

**Events** (selected; see the [full list](https://code.claude.com/docs/en/hooks)): tool events
`PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `PermissionRequest`,
`PermissionDenied`; turn events `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure`;
session events `SessionStart`, `SessionEnd`, `Setup`, `InstructionsLoaded`; agent/team events
`SubagentStart`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, …; plus `ConfigChange`,
`CwdChanged`, `FileChanged`, `WorktreeCreate`/`WorktreeRemove`, `PreCompact`/`PostCompact`,
`Notification`, `Elicitation`/`ElicitationResult`.

**Matcher**: `*` / `""` / omitted = match all; only letters/digits/`_`/`|` = an exact name or a
`|`-separated list (`Edit|Write`); anything else = a JavaScript regex (`^Notebook`,
`mcp__memory__.*` for all of one server's tools, `mcp__.*__write.*`). What it matches depends on the
event — tool name (`PreToolUse`/`PostToolUse`), session-start reason (`startup`/`resume`/`clear`/`compact`),
notification type, agent type (`SubagentStart`/`SubagentStop`), literal filenames (`FileChanged`),
command name (`UserPromptExpansion`), MCP server name (`Elicitation`); some events (`UserPromptSubmit`,
`PostToolBatch`, `Stop`, `CwdChanged`, …) take no matcher and always fire. The optional `if` field
adds permission-rule-syntax filtering on _tool_ events only: `"Bash(git *)"`, `"Edit(*.ts)"`.

**Exit codes**: **0** = success — stdout is parsed for JSON output fields (a `hookSpecificOutput`
with `permissionDecision: deny`/reason, additional context, etc.); JSON is processed _only_ on exit 0. **2** = a blocking error — stdout/JSON ignored, stderr text is fed back to Claude as the error.
**Any other code** = a non-blocking error (Claude proceeds). Only `exit 2` blocks — `exit 1` does
_not_, even though 1 is the conventional Unix failure code, so to enforce a policy use `exit 2` (or
an `exit 0` with a JSON `permissionDecision: deny`). What `exit 2` does is per-event: `PreToolUse` →
blocks the tool call; `PermissionRequest` → denies the permission; `UserPromptSubmit` → blocks
processing and erases the prompt; `UserPromptExpansion` → blocks the expansion; `Stop` → prevents
Claude from stopping (it keeps going); `PostToolUse`/`PostToolUseFailure` → can't block (the tool
already ran) — stderr is just shown to Claude; `WorktreeCreate` → any non-zero exit fails creation.

| Invoke                        | What it does                                                                                                                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| editing                       | Add a `hooks` block to a `settings.json` (user / project / local / managed), or `hooks/hooks.json` in a plugin, or `hooks` frontmatter in a skill/subagent — same format everywhere. |
| `/init` **[built-in]**        | With `CLAUDE_CODE_NEW_INIT=1` the interactive flow can scaffold hooks alongside `CLAUDE.md` as part of the reviewable proposal it presents.                                          |
| `/update-config` **[plugin]** | Programmatically writes hook definitions into `settings.json` — for "from now on, when X, run Y" automations.                                                                        |

## Validate

| Invoke                                     | What it does                                                                                                                                                                             |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/hooks` **[built-in]**                    | Opens a read-only browser of every configured hook — which lifecycle events fire which handlers, across all settings layers and enabled plugins.                                         |
| `conversation-analyzer` agent **[plugin]** | Reads your transcripts to surface repeated behaviors worth enforcing with a _new_ hook (e.g. "you keep telling Claude to run the linter after edits") — i.e. _which_ hooks should exist. |
| `harness-optimizer` agent **[plugin]**     | Judges whether the hooks you already have are well-configured — fast enough, narrowly matched, correctly ordered, and on the right events.                                               |
| `InstructionsLoaded` hook **[built-in]**   | (Itself a hook.) Log it to see exactly which instruction files loaded — useful when debugging interactions between config and hooks.                                                     |

## Improve

**Must**

- Keep hooks **fast** — sub-second where possible. Heavy work belongs on `Stop`, not `PreToolUse`/`PostToolUse`; those run synchronously and delay (or block) every matching tool call.
- Use project-owned tooling (`pnpm prettier`, `npm run lint:fix`, repo scripts), never remote one-off execution of untrusted code from a hook.
- For enforcement, use **exit code `2`** (or an `exit 0` with a JSON `permissionDecision: deny`) — `exit 1` is non-blocking, so a policy hook that exits 1 doesn't actually stop anything.

**Should**

- Scope the `matcher` narrowly — `Edit|Write`, `Bash`, `mcp__server__.*` — not a bare `*` on hot paths; use the `if` field for finer tool/argument filtering (`Bash(git *)`, `Edit(*.ts)`).
- Order hooks cheapest/most-local first: format → lint → type-check → build; reserve the full build for `Stop`, not after every edit.
- Keep hook scripts idempotent and side-effect-safe (they fire on _every_ matching event, possibly many times a session).
- Add hooks in response to observed, repeated pain (the `conversation-analyzer` agent finds these) — don't pre-emptively over-hook; each hook is per-event overhead and a maintenance burden.
- If a rule must hold _every time_, make it a hook, not a `CLAUDE.md`/skill instruction — those are requests, hooks are enforcement.
- Keep the count small (single digits) and review the set periodically with `/hooks`.

| Aspect                               | Recommendation                                                                     | Why                                                                   |
| ------------------------------------ | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------ |
| `PreToolUse` / `PostToolUse` runtime | < 1 s (a few seconds is the ceiling)                                               | runs synchronously; blocks/delays the tool call every time            |
| `Stop` / build / verify hook runtime | < ~30–60 s                                                                         | the right place for slow work — fires once per turn end, not per edit |
| Hook count                           | single digits                                                                      | each one is overhead on every matching event and a thing to maintain  |
| `matcher`                            | specific (`Edit                                                                    | Write`, `Bash`, `mcp**x**.\*`); use `if` for tool/arg filtering       | a bare `*` on a hot event taxes everything |
| Handler source                       | project-owned scripts / repo commands                                              | never run untrusted remote code from a hook                           |
| Exit codes                           | `0` = ok (JSON on stdout); **`2` = block** (stderr → Claude); other = non-blocking | only `2` blocks — `exit 1` does not                                   |
| Ordering                             | cheap/local first: format → lint → type-check → build; build on `Stop`             | don't run the full build after every edit                             |
| Idempotency                          | safe to run repeatedly                                                             | fires on every matching event                                         |
| When to reach for a hook             | a rule that must hold every time → hook, not `CLAUDE.md`/skill                     | `CLAUDE.md`/skills are requests; hooks are enforcement                |
| Context cost                         | zero unless the hook returns output                                                | output becomes a message Claude reads — keep it terse                 |

## Sources

- Hooks reference — events, matchers, the `if` field, exit codes, JSON output, hook locations — <https://code.claude.com/docs/en/hooks>
- Automate workflows with hooks (guide) — <https://code.claude.com/docs/en/hooks-guide>
- Extend Claude Code — Hook vs Skill; context cost — <https://code.claude.com/docs/en/features-overview>
- Commands (`/hooks`) — <https://code.claude.com/docs/en/commands>
