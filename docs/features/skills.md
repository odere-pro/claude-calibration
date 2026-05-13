[← README](../README.md) · [Glossary](../glossary.md) · [General setup](../general-setup.md)

# Skills

A `SKILL.md` file (plus optional supporting files) that gives Claude reusable knowledge or an
invocable workflow — `/skill-name`, or Claude loads it automatically when relevant.

## Definition

A skill = a directory with `SKILL.md` (YAML frontmatter + Markdown instructions) and optional
supporting files (`reference.md`, `examples.md`, `scripts/`). Two flavours: **reference content**
(conventions, patterns, style guides, domain knowledge — runs inline alongside your conversation
context) and **task content** (step-by-step workflows like deploy/commit/code-gen — usually invoked
directly with `/name`). **Custom commands have been merged into skills**: a `.claude/commands/foo.md`
and a `.claude/skills/foo/SKILL.md` both create `/foo` and behave the same way; the skill form adds
the directory, more frontmatter, and (optional) automatic invocation — on a name clash the skill
wins. **Context cost:** for model-invokable skills the `description` (+ `when_to_use`) of _every_
active skill sits in context on _every request_ so Claude can decide when to use it; the full body
loads only when invoked, and then **stays in context for the rest of the session** (carried across
`/compact` within a budget). So a skill's standing cost is its description, and its on-use cost is
its whole body — both matter. Claude Code skills follow the
[Agent Skills open standard](https://agentskills.io); Claude Code extends it with invocation control,
subagent execution (`context: fork`), and dynamic context injection.

## Scope

[Override-by-name](../glossary.md): on a name clash, **managed > user (personal) > project**; plugin
skills are namespaced `plugin-name:skill-name` so they never clash. The active set is the union
across all of these.

| Scope             | Path                                                                                                 | Applies to                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| managed           | the `skills/` directory in the [managed-settings location](https://code.claude.com/docs/en/settings) | everyone in the org                                                                 |
| user (personal)   | `~/.claude/skills/<name>/SKILL.md`                                                                   | all your projects                                                                   |
| project           | `.claude/skills/<name>/SKILL.md`                                                                     | this project (committed)                                                            |
| `--add-dir`       | `.claude/skills/` in an added directory                                                              | that session — an exception (other `.claude/` config isn't loaded from `--add-dir`) |
| plugin            | `<plugin>/skills/<name>/SKILL.md`                                                                    | where the plugin is enabled (namespaced)                                            |
| nested (monorepo) | `packages/x/.claude/skills/`                                                                         | discovered when Claude works under `packages/x/`                                    |

Live change detection: adding/editing/removing a skill under an already-watched `.claude/skills/`
takes effect within the session; creating a _new_ top-level skills directory needs a restart.
Visibility is also tunable from settings via `skillOverrides` — `"on"` (name + description listed) /
`"name-only"` (name only) / `"user-invocable-only"` (hidden from Claude, still in the `/` menu) /
`"off"` (hidden everywhere) — written by the `/skills` menu, without editing the skill file. Plugin
skills aren't affected by `skillOverrides`; manage those via `/plugin`.

## Configure

`SKILL.md` = YAML frontmatter + Markdown body. All fields optional; only `description` recommended.
Body structure: a `# Title`, a short overview, the instructions, then a section that links to any
supporting files (with relative Markdown links) so Claude knows what each holds and when to load it.

| Field                            | Notes                                                                                                                                                                                                                                                                                           |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`                           | display name / command; lowercase letters, numbers, hyphens; **≤ 64 chars**; defaults to the directory name                                                                                                                                                                                     |
| `description`                    | what it does **and** when to use it — Claude routes on this. Combined `description` + `when_to_use` is **truncated at 1,536 chars** in the skill listing (configurable via `maxSkillDescriptionChars`); put the key use case first so it survives truncation                                    |
| `when_to_use`                    | extra trigger phrases / example requests; appended to `description`, counts toward the 1,536-char cap                                                                                                                                                                                           |
| `argument-hint`                  | autocomplete hint, e.g. `[issue-number]` or `[filename] [format]`                                                                                                                                                                                                                               |
| `arguments`                      | named positional args for `$name` substitution (space-separated string or YAML list; names map to positions in order)                                                                                                                                                                           |
| `disable-model-invocation: true` | only _you_ can invoke it (via `/name`); its description is **removed from context entirely**, and it won't be preloaded into subagents. Use for side-effecting workflows: `/deploy`, `/commit`, `/send-slack-message`                                                                           |
| `user-invocable: false`          | only _Claude_ can invoke it; hidden from the `/` menu. Use for background knowledge that isn't a meaningful command (e.g. `legacy-system-context`)                                                                                                                                              |
| `allowed-tools`                  | tools Claude may use **without a prompt** while this skill is active — it doesn't _restrict_ (every tool stays callable; your permission settings still govern unlisted tools). For a project skill it takes effect after you trust the folder, so review project skills before trusting a repo |
| `model` / `effort`               | model / effort override while this skill is active (applies for the rest of the current turn; the session model/effort resumes next prompt)                                                                                                                                                     |
| `context: fork` (+ `agent`)      | run in a forked subagent context — the body becomes the subagent's prompt; `agent` picks the subagent type (`Explore`, `Plan`, `general-purpose`, or any custom one). Only useful for skills with an actual task, not bare guidelines                                                           |
| `hooks`                          | hooks scoped to this skill's lifecycle                                                                                                                                                                                                                                                          |
| `paths`                          | glob patterns limiting when the skill auto-activates (same format as path-scoped [rules](rules.md))                                                                                                                                                                                             |
| `shell`                          | `bash` (default) or `powershell` for `` !`cmd` `` blocks                                                                                                                                                                                                                                        |

Substitutions in the body: `$ARGUMENTS` (full string), `$ARGUMENTS[N]` / `$N` (positional, 0-based,
shell-style quoting — wrap multi-word args in quotes), `$name` (named arg), `${CLAUDE_SESSION_ID}`,
`${CLAUDE_EFFORT}`, `${CLAUDE_SKILL_DIR}` (the skill's directory — use for script paths). If you
invoke a skill with arguments it doesn't reference, Claude Code appends `ARGUMENTS: <input>` so the
input still reaches Claude. `` !`<command>` `` (or a fenced ` ```! ` block) runs a shell command and
inlines its output _before_ Claude sees the skill — preprocessing, not something Claude executes;
disable globally with `disableSkillShellExecution: true` in settings (managed/policy-friendly).

| Invoke                                | What it does                                                                                                                                                                                            |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| _(add a directory)_                   | `mkdir -p .claude/skills/<name>` + write `SKILL.md` (frontmatter + instructions, link any supporting files); or the legacy `.claude/commands/<name>.md`. No built-in generator for hand-written skills. |
| `/skills` **[built-in]**              | Lists skills; `t` sorts by token count, `Space` cycles a skill's visibility (writes `skillOverrides` to `.claude/settings.local.json`), `Enter` saves.                                                  |
| `/plugin` **[built-in]**              | Installs skills packaged in a plugin (`/reload-plugins` picks up edits to a `--plugin-dir` plugin).                                                                                                     |
| `/skill-create` **[plugin]**          | Analyzes your local git history to extract recurring coding patterns and generates `SKILL.md` files from them.                                                                                          |
| `/learn` · `/learn-eval` **[plugin]** | Extracts a reusable pattern from the current session into a skill/instinct; `-eval` self-evaluates the quality and picks the save location (global vs project) before saving.                           |
| `/evolve` **[plugin]**                | Analyzes your existing skills/instincts and suggests (or generates) restructured or merged versions.                                                                                                    |

## Validate

| Invoke                                                          | What it does                                                                                                                                                                                                                |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/skills` **[built-in]**                                        | Lists every skill; press `t` to sort by token count. Your first read on which skills are heavy, which descriptions are intact, and which are hidden — the budget check at a glance.                                         |
| `/doctor` **[built-in]**                                        | Reports whether the skill-listing budget (≈1% of the model's context window) is overflowing and which skills lost their descriptions as a result — overflow means the keywords Claude needs to match a request may be gone. |
| "What skills are available?" (just ask)                         | Quick check that a skill is registered and that its description actually contains the keywords a user would naturally say.                                                                                                  |
| `/skill-health` **[plugin]**                                    | Portfolio dashboard — per-skill size, overlap with other skills, staleness, and usage analytics across the whole skill set.                                                                                                 |
| `/learn-eval` **[plugin]**                                      | Self-grades a freshly extracted skill against quality criteria before you commit to saving it.                                                                                                                              |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Looks at the codebase and recommends skills/commands worth adding for the workflows it sees.                                                                                                                                |

If a skill isn't triggering: put keywords in the `description` that users would actually say; verify
it's listed (`What skills are available?`); rephrase your request closer to the description; or just
invoke `/skill-name`. If it triggers too often: make the `description` more specific, or add
`disable-model-invocation: true`. If it stops influencing behavior after the first response, the
content is usually still in context and the model is choosing other tools — strengthen the
`description`/instructions, re-invoke it after `/compact`, or move enforcement into a [hook](hooks.md).

## Improve

**Must**

- Keep the `description` accurate and trigger-focused, with the **key use case first** — a vague description never fires (or fires wrongly), and either way it's still in context every request. Combined with `when_to_use` it's capped at 1,536 chars; aim well under that.
- One skill = one capability. Overlapping skills compete for routing and confuse the model — split or merge, don't duplicate.
- No secrets in `SKILL.md` or supporting files (they're committed); review project skills before trusting a repo, since `allowed-tools` can grant broad access.

**Should**

- Keep `SKILL.md` **under ~500 lines**; push large reference material, API specs, and example collections into supporting files (`reference.md`, `examples.md`) that the body _links to_ — they then load only when needed.
- Keep the body itself concise even under 500 lines — once a skill loads it stays in context for the session, so every line is a recurring cost; state _what to do_, not _how_ or _why_ (the same conciseness test as [`CLAUDE.md`](claude-md.md)).
- Structure the body: `# Title` → one-paragraph overview → the instructions → "Additional resources" links to supporting files. Reference each supporting file so Claude knows its contents and when to load it.
- Use `disable-model-invocation: true` for anything with side effects (`/deploy`, `/commit`, `/send-slack-message`) — Claude shouldn't decide to deploy because your code looks ready; it also drops the description to **zero** context cost.
- Use `allowed-tools` narrowly (only the tools the skill genuinely needs without a prompt) and `paths:` to scope auto-activation to relevant files; consider `context: fork` for heavy, isolated tasks (research, codebase scans) so the work stays out of your main window.
- Prune aggressively: set unused skills `"off"` / `"name-only"` in `skillOverrides`, or delete them — an unused active skill is permanent context tax. Review with `/skills` (token sort) and `/skill-health`.
- Generate from real, observed patterns (`/skill-create`, `/learn-eval`), not speculative ones; restructure with `/evolve` when they drift; share team workflows by committing `.claude/skills/` or shipping a plugin (namespaced).
- Reach for [`.claude/rules/`](rules.md) instead when the content is always-applicable guidance rather than an on-demand workflow — rules don't need to be invoked.

| Aspect                          | Recommendation                                                                              | Why                                                                                                                                                    |
| ------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `name`                          | lowercase letters/numbers/hyphens; **≤ 64 chars**; defaults to the directory name           | hard limit; it's also the `/name` you type                                                                                                             |
| `description` (+ `when_to_use`) | key use case first; trigger keywords; aim well under the **1,536-char** combined cap        | always in context for every active skill — the single most cost-sensitive field in the whole config; on overflow the least-used skills lose their text |
| `SKILL.md` body                 | **under ~500 lines**; concise even then; structure: title → overview → instructions → links | the body stays in context for the whole session once loaded                                                                                            |
| Supporting files                | put bulk (reference docs, API specs, examples, scripts) here; link them from `SKILL.md`     | loaded only when referenced — keeps the standing cost to the description and the on-use cost to `SKILL.md`                                             |
| `disable-model-invocation`      | `true` for side-effecting workflows                                                         | Claude can't trigger it on its own; description cost → zero                                                                                            |
| `user-invocable: false`         | for background knowledge that isn't a command                                               | keeps it out of the `/` menu                                                                                                                           |
| `allowed-tools`                 | only the tools needed without a prompt; review before trusting a project                    | doesn't restrict — it pre-approves; project skills can grant broad access                                                                              |
| `context: fork`                 | for heavy isolated tasks (research, scans)                                                  | work happens in a subagent window; only the summary returns                                                                                            |
| `paths:`                        | scope auto-activation to relevant files                                                     | the skill description still loads, but it won't fire on irrelevant work                                                                                |
| One capability per skill        | split overlaps; merge near-duplicates                                                       | overlapping descriptions confuse routing                                                                                                               |
| Pruning                         | `skillOverrides` `"off"`/`"name-only"`, or delete; `/skills` token-sort + `/skill-health`   | every active skill's description is permanent context tax                                                                                              |
| Origin | generate from real patterns (`/skill-create`, `/learn-eval`); `/evolve` to restructure | speculative skills rarely fire and still cost context |
| Re-attach after `/compact`      | first 5,000 tokens per skill, 25,000-token combined budget, most-recent first               | older skills can drop entirely after compaction — re-invoke if you still need one                                                                      |

## Sources

- Skills — `SKILL.md`, frontmatter reference, substitutions, dynamic context, scopes, the 1,536-char cap, the 500-line guidance, `skillOverrides`, `context: fork`, content lifecycle, commands→skills merge — <https://code.claude.com/docs/en/skills>
- Commands — bundled skills; built-ins reachable via the Skill tool — <https://code.claude.com/docs/en/commands>
- Extend Claude Code — CLAUDE.md vs Skills vs Rules; Skill vs Subagent; context cost — <https://code.claude.com/docs/en/features-overview>
- Agent Skills open standard — <https://agentskills.io>
