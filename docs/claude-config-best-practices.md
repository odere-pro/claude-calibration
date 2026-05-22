[← README](README.md) · [Setup structure](claude-structure.md) · [Config commands](claude-config-commands.md)

# Config best practices — keeping the harness at peak performance

Per-entity requirements and recommendations. The goal: a configuration that stays **fast**,
**cheap**, and **predictable** as it grows. Each section lists **Must** items (violating them
degrades the harness) and **Should** items (good hygiene), plus _why it matters for performance_.
Numbers are grounded in the official docs — see *Sources* at the bottom.

Companions: [`claude-project-configuration.md`](claude-project-configuration.md) (what the
entities are) · [`claude-config-commands.md`](claude-config-commands.md) (how to edit them) ·
[`claude-evaluators.md`](claude-evaluators.md) (how to audit them) ·
[`claude-structure.md`](claude-structure.md) (where the files live).

---

## The performance model — what actually costs you

Three scarce things; every entity below trades against them:

| Resource | Spent by | Symptom when wasted |
|----------|----------|---------------------|
| **Context window** (every turn) | memory files (`CLAUDE.md` + `.claude/rules/*`), every *active* skill's `description`/`when_to_use` (skill-listing budget ≈ 1% of the model's context window), every MCP server's tool schemas, the subagent list | slower turns, worse attention, earlier compaction, higher cost |
| **Startup / per-tool latency** | MCP server connections, hooks on `PreToolUse`/`PostToolUse`, plugin loading (skills/agents/hooks/MCP/LSP) | laggy session start, every tool call feels heavy |
| **Token cost** | model choice, redundant context, oversized skill/agent bodies | bigger bill for the same work |

Rule of thumb: **if it's loaded but unused, delete it.** Unused skills, dead MCP servers, stale
memory lines, and near-duplicate subagents are pure tax. (`/doctor` will tell you when the
skill-listing budget overflows; `/skills` press `t` shows per-skill token cost.)

---

## Numbers & structure — concrete limits per entity

Spec-level limits (from the docs) are marked **[doc]**; the rest are rules of thumb tuned for
context economy. "Lines" assumes ~80–100 char Markdown lines.

### `CLAUDE.md` (and `.claude/rules/`)

| Aspect | Target | Notes |
|--------|--------|-------|
| Total length | **[doc]** under ~200 lines per file | "Longer files consume more context and reduce adherence." Over that → move content to `.claude/rules/` (optionally path-scoped) or `@path` imports. Imports load at launch too — they organize, they don't shrink context. |
| `@path` import depth | **[doc]** max 5 hops | relative paths resolve against the importing file |
| Headings / structure | one `#` title, then `##`/`###`, bullets | "Claude scans structure the same way readers do." |
| Specificity | concrete enough to verify | "Use 2-space indentation" beats "format code properly" |
| HTML comments | block-level `<!-- … -->` is stripped before injection | use for human-only notes; zero token cost |
| Frontmatter | none on `CLAUDE.md`; `.claude/rules/*.md` may have `paths:` | `paths`-scoped rules load only for matching files |
| `AGENTS.md` | not read by Claude Code directly | bridge: `@AGENTS.md` in `CLAUDE.md`, or `ln -s AGENTS.md CLAUDE.md` |

### `.claude/agents/*.md` — subagents

| Aspect | Target | Notes |
|--------|--------|-------|
| File structure | YAML frontmatter (`---`…`---`) + Markdown body = the system prompt | the subagent gets only this body + basic env, not the full Claude Code prompt |
| Required frontmatter | **[doc]** `name`, `description` (only these two) | other fields all optional |
| Other frontmatter | `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `effort`, `isolation`, `color`, `initialPrompt` | plugin subagents ignore `hooks`/`mcpServers`/`permissionMode` |
| `name` | **[doc]** lowercase letters + hyphens; unique within scope | filename need not match |
| `description` | 1–3 sentences with an explicit trigger phrase ("Use PROACTIVELY when…") | the orchestrator routes on this |
| `tools` | only what's needed | **[doc]** omitted ⇒ inherits *all* tools, incl. MCP — restrict with `tools` (allowlist) or `disallowedTools` (denylist) |
| `model` | cheapest capable; **[doc]** defaults to `inherit` | `haiku`/`sonnet`/`opus`, a full ID, or `inherit` |
| Body (system prompt) | ≤ ~150–200 lines | focused; never paste the codebase |

### `.claude/skills/<skill>/SKILL.md` (custom commands are merged into skills)

| Aspect | Target | Notes |
|--------|--------|-------|
| File structure | YAML frontmatter + Markdown body: overview → instructions → links to supporting files | `.claude/commands/foo.md` still works and creates `/foo` too; skill wins on a clash |
| Required frontmatter | none; `description` recommended | falls back to dir name (`name`) / first paragraph (`description`) |
| `name` | **[doc]** lowercase letters, numbers, hyphens; ≤ 64 chars; defaults to the directory name | |
| `description` + `when_to_use` | **[doc]** combined text truncated at **1,536 chars** in the skill listing (configurable via `maxSkillDescriptionChars`) | put the key use case first; this text is always in context for every active skill — the most cost-sensitive field in the whole config |
| Other frontmatter | `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model`, `effort`, `context: fork` (+ `agent`), `hooks`, `paths`, `shell` | `disable-model-invocation: true` ⇒ only you invoke it, and its description leaves context |
| `SKILL.md` body | **[doc]** keep under ~500 lines | move detail to supporting files (`reference.md`, `examples.md`, `scripts/`) loaded only when referenced |
| Skill-listing budget | ≈ 1% of model context window | raise with `skillListingBudgetFraction`; free space by setting low-priority skills to `"name-only"` in `skillOverrides` |

### `.claude/hooks/` + `settings.json` → `hooks`

| Aspect | Target | Notes |
|--------|--------|-------|
| `PreToolUse` / `PostToolUse` runtime | < 1 s | a few seconds is the ceiling — these block / delay the tool call |
| `Stop` (build/verify) hook runtime | < ~30–60 s | this is where slow work goes |
| Hook count | single digits | each runs on every matching event |
| `matcher` | specific (e.g. `Edit|Write`, `mcp__server__.*`) | `*`/empty/omitted = match all; an `if` field adds permission-syntax filtering on tool events |
| Exit codes | **[doc]** `0` = success (stdout parsed for JSON); `2` = blocking error (stderr → Claude); other = **non-blocking** | `exit 1` does **not** block — use `exit 2` (or a JSON `permissionDecision`) to enforce a policy |
| Where defined | `hooks` key in a `settings.json` (user/project/local/managed), plugin `hooks/hooks.json`, or skill/agent frontmatter | merged across all of these |

### `.mcp.json` — MCP servers

| Aspect | Target | Notes |
|--------|--------|-------|
| Connected servers | as few as you need — single digits | each server's full tool catalog (schemas) goes into context |
| Tools per server | prefer < ~20 | 50+ tools is heavy; pick a narrower server or scope it |
| Secrets | zero in the file | OAuth or env-var references only (`.mcp.json` is committed) |
| Scope | per-project for occasional servers; user-level (`~/.claude.json`) for everyday ones | a subagent-only server can go in that agent's `mcpServers` frontmatter — keeps it out of the main context |

### Plugins

| Aspect | Target | Notes |
|--------|--------|-------|
| Enabled plugins | only those in active use | a plugin's cost = the sum of its skills + agents + hooks + MCP + LSP + monitors |
| Review before enabling | always | you're importing all of the above at once |

> Don't treat the soft numbers as gates — treat them as smells. A 250-line `CLAUDE.md` or a
> 12-tool MCP server isn't *broken*; it's a prompt to ask "does this still earn its place in
> context?"

---

## `CLAUDE.md` — the instruction file

*Why it matters:* it's injected into context **every turn** (as a user message after the system
prompt). Length here is the most direct, constant drain you control.

**Must**
- No secrets, tokens, or internal URLs — it's committed. Point at `.env.example` or a vault.
- Only enforceable, concrete instructions. If you wouldn't actually run/check it, don't write it — Claude follows it literally. For something that *must* run at a fixed point, use a hook.
- Keep nested files non-contradictory; discovered files are *concatenated* (closer read last), not "the closest wins", so don't restate — only differ.

**Should**
- Keep it short — **under ~200 lines**. Long files dilute attention more than they help.
- Put exact commands in backticks so they run verbatim; use headers and bullets.
- Move shared / bulky content into `.claude/rules/*.md` (path-scoped where possible) or `@path` imports rather than inlining everything.
- Bridge `AGENTS.md` from `CLAUDE.md` (`@AGENTS.md` or a symlink) so every tool reads one source of truth — Claude Code does **not** read `AGENTS.md` on its own.
- Update it in the same PR as the workflow change it describes; periodically remove outdated/conflicting lines.
- Don't restate the README — link to it.

## `.claude/settings.json` (+ `settings.local.json`)

*Why it matters:* permissions drive interruption frequency; `env`/`model` shape cost; misconfig
shows up as friction or surprises from the precedence chain.

**Must**
- No secrets in committed `settings.json`; machine-specific values go in `settings.local.json` (git-ignored).
- Never run with `--dangerously-skip-permissions`. Use a real allowlist instead.
- Know the precedence chain (managed → CLI args → project `.local` → project → user) before debugging "why is this setting ignored".

**Should**
- Tighten `permissions`: allowlist common read-only/safe commands to cut prompt friction (`/fewer-permission-prompts` proposes the list), but never blanket-allow destructive operations.
- Keep `env` minimal.
- Don't pin a `model` in committed settings unless the team agrees; otherwise let task-appropriate routing apply (Haiku = frequent/cheap, Sonnet = main dev, Opus = deep reasoning only).
- Set a sane `cleanupPeriodDays` so transcript/state growth stays bounded.
- Sanity-check with `/doctor`; deeper review with `harness-optimizer` (plugin).

## `.claude/agents/*.md` — subagents

*Why it matters:* the orchestrator sees every agent's name + description on every routing
decision; each agent's tool set and model affect its own speed and cost.

**Must**
- Restrict each agent's `tools` (or use `disallowedTools`) — omitting `tools` inherits *all* tools, including MCP; extra tools mean more schema in its context and more ways to go wrong.
- No name collisions you didn't intend; precedence is managed > `--agents` flag > project > user > plugin.

**Should**
- Write a sharp, single-purpose `description` with strong routing cues so the right agent fires.
- Pick the cheapest capable `model`: Haiku for narrow reviewers/workers, Sonnet for orchestration, Opus rarely. (`model` defaults to `inherit`.)
- Keep the system-prompt body focused; don't paste the codebase into it.
- Consolidate near-duplicate agents instead of accumulating them.
- Run independent agents in parallel (one message, multiple Agent calls).
- Put a subagent-only MCP server in that agent's `mcpServers` frontmatter, not `.mcp.json`, so its tool descriptions don't burden the main conversation.

## `.claude/skills/<skill>/SKILL.md` (and `.claude/commands/*.md`)

*Why it matters:* every **active** skill's `description`/`when_to_use` sits in context permanently
(that's how auto-invocation works); only the body loads on use, and once loaded it stays for the
session.

**Must**
- Keep the `description` accurate and trigger-focused, key use case first — a vague description never fires (or fires wrongly) and still costs context.
- One skill = one capability. Overlapping skills compete and confuse routing.

**Should**
- Keep `SKILL.md` under ~500 lines; push large reference material into supporting files the skill *points to* (progressive disclosure).
- Prune aggressively: set unused skills to `"off"`/`"name-only"` in `skillOverrides`, add `disable-model-invocation: true`, or delete them — an unused active skill is permanent context tax. Review with `/skills` (sort by token count) and `/skill-health` (plugin).
- Use `disable-model-invocation: true` for side-effecting workflows (`/deploy`, `/commit`) so Claude can't trigger them on its own.
- Generate from real, observed patterns (`/skill-create`, `/learn-eval` — plugin) rather than speculative ones; restructure with `/evolve` (plugin) when they drift.

## `.claude/hooks/` + `settings.json` → `hooks`

*Why it matters:* hooks run **synchronously** and many can block or delay tool calls; a slow hook
taxes every matching action all session long.

**Must**
- Keep hooks fast — sub-second where possible. Heavy work belongs on `Stop`, not `PreToolUse`/`PostToolUse`.
- Use project-owned tooling (`pnpm prettier`, repo scripts), never remote one-off execution of untrusted code.
- Fail loudly with an actionable message; use **exit code `2`** (or a JSON `permissionDecision`) to actually block — `exit 1` is treated as non-blocking.

**Should**
- Scope `matcher` narrowly (`Edit|Write`, not `*`); use the `if` field for finer tool/argument filtering.
- Order cheapest/most-local first: format → lint → type-check → build; reserve full build for `Stop`.
- Keep hooks idempotent and side-effect-safe.
- Add hooks in response to observed, repeated pain (the `conversation-analyzer` agent — plugin — finds these) — don't over-hook.

## `.mcp.json` — MCP servers

*Why it matters:* each connected server injects its **full tool catalog** (schemas) into context
and adds a startup connection. Unused or chatty servers are one of the biggest silent context
sinks.

**Must**
- No hardcoded tokens — `.mcp.json` is committed. Use OAuth or env-var-referenced secrets.
- Only list servers you actually use; remove the rest.

**Should**
- Prefer servers with small, well-scoped tool surfaces; drop noisy ones.
- Pin versions; vet or self-host critical servers; re-audit periodically.
- Use `/mcp` to spot and reconnect dead servers (a dead entry still costs a startup attempt).
- Need a server only occasionally? Add it per-project where it's used, not globally; for subagent-only use, define it in the subagent's `mcpServers` frontmatter.

## Plugins (user-level, layered onto the project)

*Why it matters:* a plugin adds its skills, agents, hooks, MCP servers, LSP servers, and monitors
— so it multiplies every cost above at once.

**Must**
- Review what a plugin ships (and trust its marketplace) before enabling it.

**Should**
- Install only what you use; disable rather than uninstall if you might want it back; prune periodically.
- Keep plugins updated (`/reload-plugins` after edits).
- Watch for command/agent name collisions across plugins (plugin skills are namespaced, so they can't clash with each other or with your own).
- Use `/claude-code-setup:claude-automation-recommender` (plugin) to decide what's actually worth having.

---

## Always-on checklist

- [ ] `CLAUDE.md` is < ~200 lines, concrete, secret-free; bulk content lives in `.claude/rules/`
- [ ] `AGENTS.md` (if present) is bridged from `CLAUDE.md` via `@AGENTS.md` or a symlink
- [ ] Permissions allowlist covers the safe-and-frequent; nothing destructive is blanket-allowed
- [ ] No secrets in any committed file (`settings.json`, `.mcp.json`, `commands/`, `agents/`, memory)
- [ ] Subagents have minimal/explicit `tools` (not the inherit-all default), sharp descriptions, cheapest capable model
- [ ] Active skills are non-overlapping with key-use-case-first descriptions; unused ones are `skillOverrides`-off or deleted
- [ ] Hooks are sub-second, narrowly matched, locally sourced, ordered cheap→expensive (heavy work on `Stop`), and use `exit 2` to block
- [ ] `.mcp.json` lists only servers in active use; tokens are OAuth/env-referenced; dead servers cleaned up
- [ ] Only plugins in active use are enabled
- [ ] Anything the team needs is committed; nothing critical lives only in someone's `~/.claude/`
- [ ] Periodic audit: `/doctor` → `/skills` (token sort) → (plugin) `harness-optimizer` → `claude-automation-recommender` → `claude-md-improver`
- [ ] For large tasks: don't work in the last ~20% of the context window — `/compact` or start fresh; route model to task complexity

---

## Sources

- Memory (CLAUDE.md size/structure, `.claude/rules/`, imports) — <https://code.claude.com/docs/en/memory>
- Skills (SKILL.md ≤ 500 lines, `name` ≤ 64 chars, 1,536-char description cap, listing budget, `skillOverrides`, commands→skills merge) — <https://code.claude.com/docs/en/skills>
- Subagents (required `name`+`description`, full field list, `tools` inherit-all default, `model` defaults to `inherit`) — <https://code.claude.com/docs/en/sub-agents>
- Hooks (events, exit codes — only `2` blocks, matchers) — <https://code.claude.com/docs/en/hooks>
- Settings (keys, precedence) — <https://code.claude.com/docs/en/settings> · Commands — <https://code.claude.com/docs/en/commands>
- MCP — <https://code.claude.com/docs/en/mcp> · Plugins — <https://code.claude.com/docs/en/plugins>
- Best practices (write an effective CLAUDE.md) — <https://code.claude.com/docs/en/best-practices>
