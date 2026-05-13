# Evaluators — Claude Code skills, agents & commands

Everything that **evaluates, audits, scores, or recommends** — grouped by what it acts on.
Tables: column 1 is how you invoke it, column 2 is what it does in one sentence.

> **Provenance — read this first.** Claude Code *itself* ships only a handful of evaluator-ish
> tools: built-in commands (`/doctor`, `/status`), bundled skills (`/simplify`, `/debug`,
> `/fewer-permission-prompts`), built-in subagents (`Explore`, `Plan`, `general-purpose`), and a
> couple of built-ins reachable via the Skill tool (`/review`, `/security-review`). **Almost
> everything else below** — `harness-optimizer`, `conversation-analyzer`, `code-reviewer` and the
> language reviewers, `comment-analyzer`, `type-design-analyzer`, `pr-test-analyzer`,
> `silent-failure-hunter`, `gan-evaluator`, `/skill-health`, `/learn-eval`, `/evolve`,
> `/instinct-status`, `claude-code-guide`, `/claude-code-setup:claude-automation-recommender`,
> `/claude-md-management:claude-md-improver`, `eval-harness`, `verification-loop`, … — comes from
> **plugins** (official ones include `claude-code-setup`, `claude-md-management`, `pr-review-toolkit`)
> or this user's setup. Check / install with `/plugin`. Items below are tagged **[built-in]**,
> **[bundled skill]**, or **[plugin]**; agents without a tag are plugin/setup-provided subagents.

Companions: [`claude-project-configuration.md`](claude-project-configuration.md) (the entities) ·
[`claude-config-commands.md`](claude-config-commands.md) (commands that *update / improve* the same
entities) · [`claude-structure.md`](claude-structure.md) (where every file lives).

**Invocation legend**

| Form | How to invoke |
|------|---------------|
| `/command` **[built-in]** | typed at the prompt; the CLI handles it |
| `/name` **[bundled skill]** | typed at the prompt, or the Skill tool |
| `/name` / `/plugin:name` | a skill from a plugin or your setup (namespaced ones come from a plugin) |
| `name` agent | a subagent — Agent tool with that `subagent_type` (these are plugin/setup-provided unless noted built-in) |

---

## Configuration entities

### `CLAUDE.md` / `AGENTS.md` — the instruction file

| Invoke | What it does |
|--------|--------------|
| `/claude-md-management:claude-md-improver` **[plugin]** | Scans every `CLAUDE.md`/`AGENTS.md`, scores it against quality templates, and applies targeted fixes. |
| `/memory` **[built-in]** | Lists the memory files actually loaded this session (`CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/*`) so you can review and edit them. |
| `/doctor` **[built-in]** | Among other checks, reports whether the skill-listing budget is overflowing (which can starve skill descriptions). |

### `.claude/settings.json` (+ `settings.local.json`)

| Invoke | What it does |
|--------|--------------|
| `/doctor` **[built-in]** | Diagnoses the install and reports broken, invalid, or conflicting settings. |
| `/status` **[built-in]** | Shows which `settings.json` files are loaded and the resulting active configuration. |
| `harness-optimizer` agent | Reviews settings, hooks, and model routing for reliability, cost, and throughput, then proposes concrete changes. |
| `/fewer-permission-prompts` **[bundled skill]** | Mines past transcripts for safe repeated calls and proposes a tighter `permissions` allowlist. |
| `claude-code-guide` agent | Answers whether a given key/value is valid and how it should be set. |

### `.claude/agents/*.md` — subagents

| Invoke | What it does |
|--------|--------------|
| `harness-optimizer` agent | Reviews subagent definitions (tools, model, prompt scope) as part of a harness audit. |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Analyzes the codebase and recommends which subagents to add. |
| `/agents` **[built-in]** | Lists the effective subagents so you can inspect and edit them. |

### `.claude/commands/*.md` & `.claude/skills/<name>/SKILL.md` — slash commands / skills

| Invoke | What it does |
|--------|--------------|
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Recommends commands/skills that fit the codebase's workflows. |
| `claude-code-guide` agent | Validates command/skill file syntax and frontmatter. |

### `.claude/skills/<skill>/SKILL.md` — skills

| Invoke | What it does |
|--------|--------------|
| `/skills` **[built-in]** | Lists skills with token counts; press `t` to sort by token cost — your first read on which skills are heavy. |
| `/doctor` **[built-in]** | Reports whether the skill-listing budget overflows and which skills lose their descriptions. |
| `/skill-health` **[plugin]** | Portfolio dashboard with per-skill size, overlap, staleness, and usage analytics. |
| `/learn-eval` **[plugin]** | Self-grades a freshly extracted skill before deciding whether and where to save it. |
| `/evolve` **[plugin]** | Suggests restructured or merged versions of existing skills/instincts. |
| `/instinct-status` **[plugin]** | Lists learned instincts with confidence scores. |

### `.claude/hooks/` + `settings.json` → `hooks`

| Invoke | What it does |
|--------|--------------|
| `/hooks` **[built-in]** | Lists configured hooks and the events that fire them, for review. |
| `conversation-analyzer` agent | Reads transcripts to surface repeated behaviors worth enforcing with a new hook. |
| `harness-optimizer` agent | Judges whether the hooks you already have are well-configured and correctly ordered. |

### `.mcp.json` — MCP servers

| Invoke | What it does |
|--------|--------------|
| `/mcp` **[built-in]** | Lists configured servers with connection and OAuth status, for review. |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Recommends MCP servers worth adding for this codebase. |
| `claude-code-guide` agent | Answers MCP config questions and sanity-checks the file. |

### Plugins (user-level, layered onto the project)

| Invoke | What it does |
|--------|--------------|
| `/plugin` **[built-in]** | Browses installed/available plugins so you can see what's enabled. |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Recommends plugins to install based on the codebase. |
| `/skill-health` **[plugin]** | Covers the skills a plugin contributes in the portfolio dashboard. |

### Whole config at once (cross-cutting)

| Invoke | What it does |
|--------|--------------|
| `/doctor` **[built-in]** | Runs a one-shot health check across the install and all configuration. |
| `harness-optimizer` agent | Answers "is what I have configured well?" and tunes the existing harness. |
| `/claude-code-setup:claude-automation-recommender` **[plugin]** | Answers "what am I missing?" and recommends additions across every entity. |

> **Quick start:** `/doctor` for the built-in health check → (if installed)
> `/claude-code-setup:claude-automation-recommender` for a recommendations pass →
> `harness-optimizer` agent to tune what exists → `/skills` (or `/skill-health`) for the skills →
> `/claude-md-management:claude-md-improver` for the instruction files.

---

## Beyond config

These evaluate **code** or a **running app**, not `.claude/`. Built-ins are tagged; the rest are
plugin/setup-provided.

### Code

| Invoke | What it does |
|--------|--------------|
| `/review` · `/security-review` **[built-in]** | Reviews a PR (or pending branch changes) for issues; `/security-review` focuses on vulnerabilities. |
| `/simplify` **[bundled skill]** | Reviews recently changed files for reuse, quality, and efficiency, and applies fixes. |
| `/debug` **[bundled skill]** | Enables debug logging and walks through diagnosing a failure. |
| `code-reviewer` agent + `<lang>-reviewer` agents (`typescript-`, `python-`, `go-`, `rust-`, `java-`, `kotlin-`, `csharp-`, `cpp-`, `flutter-`, `database-`, `healthcare-`) | Reviews a diff for bugs, style, and that language's idioms. |
| `security-reviewer` agent | Scans code for OWASP-class vulnerabilities and leaked secrets. |
| `type-design-analyzer` agent | Rates a type's encapsulation, invariants, usefulness, and enforcement. |
| `silent-failure-hunter` agent | Finds swallowed errors, empty catches, and bad fallback behavior. |
| `comment-analyzer` agent | Checks comments for accuracy and comment-rot risk. |
| `pr-test-analyzer` agent · `/test-coverage` **[plugin]** | Assesses whether tests meaningfully cover new behavior and edge cases. |
| `code-simplifier` agent | Flags redundancy and over-complexity in recently changed code. |
| `/quality-gate` **[plugin]** | Runs an aggregate quality gate over the change. |
| `performance-optimizer` agent | Identifies performance bottlenecks and proposes fixes. |
| `a11y-architect` agent | Audits UI against WCAG accessibility requirements. |
| `seo-specialist` agent | Audits pages for technical SEO issues. |

### Running app / model output

| Invoke | What it does |
|--------|--------------|
| `gan-evaluator` agent | Drives the live app via Playwright, scores it against a rubric, and feeds feedback back to the generator. |
| `eval-harness` skill | Builds and runs an evaluation harness for an LLM feature. |
| `verification-loop` skill | Runs a structured verify-then-retry loop until output meets criteria. |
| `e2e-runner` agent | Generates and runs end-to-end tests for critical user flows. |

---

## Sources

- Commands reference (built-in commands, bundled skills, Skill-tool-reachable built-ins) — <https://code.claude.com/docs/en/commands>
- Skills (`/skills`, `skillOverrides`, listing budget, `/doctor` budget check) — <https://code.claude.com/docs/en/skills>
- Subagents (built-in `Explore`/`Plan`/`general-purpose`) — <https://code.claude.com/docs/en/sub-agents>
- Settings — <https://code.claude.com/docs/en/settings> · Memory — <https://code.claude.com/docs/en/memory> · Hooks — <https://code.claude.com/docs/en/hooks>
- Plugins (browse/install with `/plugin`) — <https://code.claude.com/docs/en/plugins>
