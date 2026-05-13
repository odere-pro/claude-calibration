# Claude Code configuration — docs

How a Claude Code setup is structured, and for each piece: what it is, how to **configure** it, how
to **validate** it, how to **improve** it, and its **scoping**. Facts are grounded in the official
docs (`code.claude.com/docs/*`) and `agents.md`; every page carries a **Sources** section.

Start with [**`glossary.md`**](glossary.md) (the vocabulary, aligned with Claude Code's own terms),
then [**`general-setup.md`**](general-setup.md) (the whole picture), then the [feature](#features)
you care about.

## How these docs are organized

- **One page per thing**, organized vertically: read a feature's page and you have its whole story
  — definition, scope, configure, validate, improve — without jumping around.
- **DRY**: a fact lives in exactly one page; other pages link to it. Scope / precedence / layering
  rules live in `general-setup.md` (or the owning feature page) and are linked, not restated.
- **One template** for every feature page (and `general-setup.md`):

  ```
  # <Feature>            — the official feature name
  one-line definition.
  ## Definition          — what it is, what files back it, what it does, its context cost & load timing
  ## Scope               — the scopes it can live at + how it layers (additive / override-by-name) + precedence
  ## Configure           — file format, the fields/limits that matter, the commands & skills that create/edit it
  ## Validate            — built-in checks (/doctor, /status, /skills, /mcp, /context, …) + audit tools
  ## Improve             — Must / Should hygiene + a "Limits" table (concrete numbers) + tools that improve it
  ## Sources             — official doc links
  ```

  Commands marked **[built-in]** (the CLI), **[bundled skill]** (ships with Claude Code), or
  **[plugin]** (installed via a plugin — check/install with `/plugin`).

## Index

| Page                                   | Covers                                                                                                                                                                                                   |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`glossary.md`](glossary.md)           | The vocabulary: feature, scope, layering, precedence, CLAUDE.md, auto memory, importing AGENTS.md, frontmatter, built-in command, bundled skill, marketplace, context cost                               |
| [`general-setup.md`](general-setup.md) | The setup as a whole — the extension layer, the `.claude/` layout, scopes & precedence & layering, the `AGENTS.md` import, the context-cost model, the always-on checklist; how to validate & improve it |

### Features

| Page                                             | Covers                                                                            |
| ------------------------------------------------ | --------------------------------------------------------------------------------- |
| [`features/claude-md.md`](features/claude-md.md) | `CLAUDE.md` (+ `CLAUDE.local.md`, auto memory, importing `AGENTS.md`)             |
| [`features/rules.md`](features/rules.md)         | `.claude/rules/` — topic / path-scoped instruction files                          |
| [`features/settings.md`](features/settings.md)   | `.claude/settings.json` (+ `.local`, managed)                                     |
| [`features/commands.md`](features/commands.md)   | Built-in commands & bundled skills (the `/…` reference); custom commands → skills |
| [`features/skills.md`](features/skills.md)       | `.claude/skills/<name>/SKILL.md` authoring (+ legacy `.claude/commands/*.md`)     |
| [`features/subagents.md`](features/subagents.md) | `.claude/agents/*.md`                                                             |
| [`features/hooks.md`](features/hooks.md)         | `.claude/hooks/` + `settings.json` → `hooks`                                      |
| [`features/mcp.md`](features/mcp.md)             | `.mcp.json` (+ `~/.claude.json`, `managed-mcp.json`)                              |
| [`features/plugins.md`](features/plugins.md)     | Plugin layout, marketplaces, lifecycle                                            |

### Reference

| Page                                                       | Covers                                                                                                       |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| [`reference/agents-md.md`](reference/agents-md.md)         | The `AGENTS.md` open standard + how Claude Code maps to it (import / symlink, behavioral equivalence)        |
| [`reference/beyond-config.md`](reference/beyond-config.md) | Tools that evaluate **code** or a **running app** — out of scope of `.claude/` config, kept for completeness |

## Sources

- Extend Claude Code — <https://code.claude.com/docs/en/features-overview> · Overview — <https://code.claude.com/docs/en/overview>
- Settings — <https://code.claude.com/docs/en/settings> · Memory — <https://code.claude.com/docs/en/memory> · Subagents — <https://code.claude.com/docs/en/sub-agents>
- Skills — <https://code.claude.com/docs/en/skills> · Hooks — <https://code.claude.com/docs/en/hooks> · MCP — <https://code.claude.com/docs/en/mcp> · Plugins — <https://code.claude.com/docs/en/plugins> · Commands — <https://code.claude.com/docs/en/commands>
- AGENTS.md open standard — <https://agents.md>
