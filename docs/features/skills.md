[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Skills

A `SKILL.md` file (plus optional supporting files) that gives Claude reusable knowledge or an
invocable workflow — `/skill-name`, or Claude loads it automatically when relevant.

## Definition

A skill = a directory with `SKILL.md` (YAML frontmatter + Markdown instructions) and optional
supporting files (`reference.md`, `examples.md`, `scripts/`). Two flavours: **reference content**
(conventions, patterns, domain knowledge — runs inline alongside your conversation) and **task
content** (step-by-step workflows like deploy/commit — usually invoked directly). **Custom commands
have been merged into skills**: a `.claude/commands/foo.md` and a `.claude/skills/foo/SKILL.md` both
create `/foo`; the skill form adds the directory, more frontmatter, and automatic invocation. On a
name clash the skill wins. **Context cost:** the `description` (+ `when_to_use`) of every
model-invokable skill is in context every request; the full body loads only when invoked and then
stays for the session (carried across `/compact` within a budget). Claude Code skills follow the
[Agent Skills open standard](https://agentskills.io); Claude Code adds invocation control, subagent
execution (`context: fork`), and dynamic context injection.

## Scope

[Override-by-name](../glossary.md): on a name clash, **managed > user (personal) > project**;
plugin skills are namespaced `plugin-name:skill-name` so they never clash. The active set is the
union across all of these.

| Scope | Path | Applies to |
|-------|------|-----------|
| managed | the [managed-settings directory](https://code.claude.com/docs/en/settings)'s `skills/` | everyone in the org |
| user (personal) | `~/.claude/skills/<name>/SKILL.md` | all your projects |
| project | `.claude/skills/<name>/SKILL.md` | this project (committed) |
| `--add-dir` | `.claude/skills/` in an added directory | that session (an exception — other `.claude/` config isn't loaded from `--add-dir`) |
| plugin | `<plugin>/skills/<name>/SKILL.md` | where the plugin is enabled (namespaced) |
| nested | `packages/x/.claude/skills/` | discovered when Claude works under `packages/x/` (monorepo) |

Live change detection: adding/editing/removing a skill under an already-watched `.claude/skills/`
takes effect within the session; creating a *new* top-level skills directory needs a restart.
Visibility is also tunable from settings via `skillOverrides` (`"on"` / `"name-only"` /
`"user-invocable-only"` / `"off"` — the `/skills` menu writes it) without editing the skill file —
except plugin skills, which you manage via `/plugin`.

## Configure

`SKILL.md` = YAML frontmatter + Markdown body. All fields optional; only `description` recommended.

| Field | Notes |
|-------|-------|
| `name` | display name / command; lowercase letters, numbers, hyphens; **≤ 64 chars**; defaults to the directory name |
| `description` | what it does **and** when to use it — Claude routes on this. Combined `description` + `when_to_use` is truncated at **1,536 chars** in the skill listing (configurable via `maxSkillDescriptionChars`). Put the key use case first. |
| `when_to_use` | extra trigger phrases / example requests; appended to `description`, counts toward the 1,536-char cap |
| `argument-hint` | autocomplete hint, e.g. `[issue-number]` |
| `arguments` | named positional args for `$name` substitution |
| `disable-model-invocation: true` | only you can invoke it; its description leaves context entirely (use for side-effecting workflows: `/deploy`, `/commit`) |
| `user-invocable: false` | only Claude can invoke it (background knowledge, not a meaningful command) |
| `allowed-tools` | tools Claude may use without a prompt while this skill is active (doesn't restrict — your permission settings still govern unlisted tools; for project skills, takes effect after you trust the folder) |
| `model` / `effort` | model / effort override while this skill is active (applies for the rest of the turn) |
| `context: fork` (+ `agent`) | run in a forked subagent context — the body becomes the subagent's prompt; `agent` picks the subagent type (`Explore`, `Plan`, `general-purpose`, or a custom one) |
| `hooks` | hooks scoped to this skill's lifecycle |
| `paths` | glob patterns that limit when the skill auto-activates (same format as path-scoped [rules](rules.md)) |
| `shell` | `bash` (default) or `powershell` for `` !`cmd` `` blocks |

Substitutions in the body: `$ARGUMENTS`, `$ARGUMENTS[N]` / `$N`, `$name`, `${CLAUDE_SESSION_ID}`,
`${CLAUDE_EFFORT}`, `${CLAUDE_SKILL_DIR}`. `` !`<command>` `` (or a fenced ` ```! ` block) runs a
shell command and inlines its output *before* Claude sees the skill — disable with
`disableSkillShellExecution: true` in settings. Reference supporting files from `SKILL.md` so
Claude knows what they hold and when to load them.

| Invoke | What it does |
|--------|--------------|
| *(add a directory)* | `mkdir -p .claude/skills/<name>` + `SKILL.md`; or the legacy `.claude/commands/<name>.md`. No built-in generator. |
| `/skills` **[built-in]** | List skills; `t` sort by token cost; `Space` toggle visibility (writes `skillOverrides`). |
| `/plugin` **[built-in]** | Install skills packaged in a plugin (`/reload-plugins` picks up edits). |
| `/skill-create` **[plugin]** | Generate a `SKILL.md` from coding patterns in your git history. |
| `/learn` · `/learn-eval` **[plugin]** | Extract a reusable pattern from the session into a skill/instinct (`-eval` self-grades first). |
| `/evolve` **[plugin]** | Restructure or merge existing skills/instincts. |

## Validate

| Invoke | What it does |
|--------|--------------|
| `/skills` **[built-in]** | Lists skills; `t` sorts by token cost — your first read on which skills are heavy and whether descriptions are intact. |
| `/doctor` **[built-in]** | Reports whether the skill-listing budget overflows and which skills lost their descriptions. |
| "What skills are available?" | Quick check that a skill is registered and its description has the keywords you'd say. |
| `/skill-health` **[plugin]** | Portfolio dashboard — per-skill size, overlap, staleness, usage. |
| `/learn-eval` **[plugin]** | Self-grades a freshly extracted skill before deciding whether/where to save it. |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Recommends skills/commands worth adding for the codebase. |

If a skill isn't triggering: keywords in the description users would say; verify it's listed;
rephrase your request closer to the description; or invoke `/skill-name` directly. If it triggers
too often: make the description more specific, or add `disable-model-invocation: true`.

## Improve

**Must**
- Keep the `description` accurate and trigger-focused, key use case first — a vague description never fires (or fires wrongly) and still costs context every request.
- One skill = one capability. Overlapping skills compete and confuse routing.

**Should**
- Keep `SKILL.md` **under ~500 lines**; push large reference material into supporting files the skill *points to* (progressive disclosure) — they load only when needed.
- Keep the body concise — once loaded it stays for the session; state what to do, not how/why (the same conciseness test as [`CLAUDE.md`](claude-md.md)).
- Use `disable-model-invocation: true` for side-effecting workflows (`/deploy`, `/commit`) so Claude can't trigger them on its own — also drops the description to zero context cost.
- Prune aggressively: set unused skills `"off"` / `"name-only"` in `skillOverrides`, or delete them — an unused active skill is permanent context tax. Review with `/skills` (token sort) and `/skill-health` (plugin).
- Generate from real, observed patterns (`/skill-create`, `/learn-eval`); restructure with `/evolve` when they drift.
- Reach for [`.claude/rules/`](rules.md) instead when the content is always-applicable guidance rather than an on-demand workflow.

| Limit | Value | Note |
|-------|-------|------|
| `name` | ≤ 64 chars, lowercase letters/numbers/hyphens | defaults to the directory name |
| `description` + `when_to_use` | ≤ 1,536 chars in the listing | configurable via `maxSkillDescriptionChars`; put the key use case first |
| `SKILL.md` body | keep under ~500 lines | move detail to supporting files |
| Skill-listing budget | ≈ 1% of the model's context window | raise via `skillListingBudgetFraction` / `SLASH_COMMAND_TOOL_CHAR_BUDGET`; free space by setting low-priority skills `"name-only"` in `skillOverrides`; `/doctor` reports overflow |
| Re-attach after `/compact` | first 5,000 tokens per skill, 25,000-token combined budget | most-recently-invoked first; older skills may drop |

## Sources

- Skills (SKILL.md, frontmatter, scopes, caps, commands→skills merge, `skillOverrides`, `context: fork`) — <https://code.claude.com/docs/en/skills>
- Commands (bundled skills; built-ins via Skill tool) — <https://code.claude.com/docs/en/commands>
- Extend Claude Code (CLAUDE.md vs Skills vs Rules; context cost) — <https://code.claude.com/docs/en/features-overview>
- Agent Skills open standard — <https://agentskills.io>
