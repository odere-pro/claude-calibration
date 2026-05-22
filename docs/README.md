# Claude Code configuration — docs

How a Claude Code setup is structured, and for each piece: what it is, how to **configure** it, how
to **validate** it, how to **improve** it, and its **scoping**. Facts are grounded in the official
docs (`code.claude.com/docs/*`) and `agents.md`; every page carries a **Sources** section.

Start with [**`glossary.md`**](glossary.md) (the vocabulary, aligned with Claude Code's own terms),
then [**`claude-structure.md`**](claude-structure.md) (the whole picture), then the [feature](#features)
you care about.

For driving the `claude-calibration` plugin that _uses_ this doc-set, see
[**`install.md`**](install.md) (install / verify / update / uninstall) and
[**`usage.md`**](usage.md) (intents, the recurrence → enforcement-creation flow, per-feature
shortcuts, reading the run-folder files). Maintaining or releasing the plugin? See
[**`RELEASING.md`**](RELEASING.md).

## How these docs are organized

The primary reader of these pages is an **agent** grading a setup against them — each bundle's
`reference.md` is extracted from the matching `features/*.md`, and the evaluator falls back to
reading the feature pages directly. So the pages are authored to be **parsed deterministically, not
just browsed**. See [`SOFTWARE-3-0.md`](../SOFTWARE-3-0.md) for *why* the doc-set is shaped for
agents.

### Authoring principles

1. **Front-load.** A one-line definition sits directly under the title; the most load-bearing fact
   leads each section. An agent should land, parse, and score without reading to the end.
2. **One page per thing**, organized vertically: a feature's page carries its whole story —
   definition, scope, configure, validate, improve — without jumping around.
3. **One fact, one page (DRY).** A fact lives in exactly one page; others link to it. Scope /
   precedence / layering live in `claude-structure.md` (or the owning feature page) and are linked,
   not restated. Cross-links are **anchored** (`page.md#section`) so navigation is deterministic.
4. **One fixed shape per page-type.** Feature pages use the template below; reference pages use
   purpose-line → sections → Sources.
5. **Machine-readable rubric.** `Must` / `Should` / `Limit` tables carry concrete numbers; pattern
   signatures are written **verbatim**.
6. **Signatures are a stable contract.** A signature (`<feature>:<short-name>`) is never renamed —
   it ties a page to its bundle's `reference.md`, `scripts/lint.sh`, and `rules/dispatch.md` (see
   the [signature contract](../CONTRIBUTING.md#the-signature-contract-read-before-touching-findings)).
7. **Consistent navigation.** Every non-feature page opens with the same breadcrumb; every page
   ends with a **Sources** block of official doc links.

The feature-page template:

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

| Page                                       | Covers                                                                                                                                                                                                   |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`glossary.md`](glossary.md)               | The vocabulary: feature, scope, layering, precedence, CLAUDE.md, auto memory, importing AGENTS.md, frontmatter, built-in command, bundled skill, marketplace, context cost                               |
| [`claude-structure.md`](claude-structure.md) | The setup as a whole — config across global / project / plugin / enterprise layers, the `.claude/` layout, scopes & precedence & layering, the context-cost model                                       |
| [`install.md`](install.md)                 | Driving the plugin — install via marketplace / `--plugin-dir` / `--plugin-url`, enable/disable/uninstall, verify (`/plugin`, `/skills`, `/agents`, `/context`), update, troubleshooting                  |
| [`usage.md`](usage.md)                     | Driving the plugin — your first run, setting an intent, resume/restart/status, per-feature usage, the recurrence → enforcement-creation flow, reading the run-folder files, reverting, limits            |
| [`self-calibration.md`](self-calibration.md) | How the plugin evaluates a setup — the four entry points (doctor/audit/calibrate/diff), the 6-phase loop, worker subagents + models, signatures/dispatch, write-guards, and auditing this plugin against itself     |
| [`evaluating-agentic-workflows.md`](evaluating-agentic-workflows.md) | Methodology for evaluating multi-agent / multi-skill workflows (e.g. a PR code-review pipeline) — the node / edge / flow levels, reusing the severity + intent-flow scales, case sets, and recurrence → enforcement |
| [`RELEASING.md`](RELEASING.md)             | Maintainers — versioning, the gate suite, tagging, and publishing to the marketplace                                                                                                                    |

### Features

| Page                                             | Covers                                                                            |
| ------------------------------------------------ | --------------------------------------------------------------------------------- |
| [`features/claude-md.md`](features/claude-md.md) | `CLAUDE.md` (+ `CLAUDE.local.md`, auto memory, importing `AGENTS.md`)             |
| [`features/rules.md`](features/rules.md)         | `.claude/rules/` — topic / path-scoped instruction files                          |
| [`features/settings.md`](features/settings.md)   | `.claude/settings.json` (+ `.local`, managed)                                     |
| [`features/skills.md`](features/skills.md)       | `.claude/skills/<name>/SKILL.md` authoring (+ legacy `.claude/commands/*.md`)     |
| [`features/subagents.md`](features/subagents.md) | `.claude/agents/*.md`                                                             |
| [`features/hooks.md`](features/hooks.md)         | `.claude/hooks/` + `settings.json` → `hooks`                                      |
| [`features/mcp.md`](features/mcp.md)             | `.mcp.json` (+ `~/.claude.json`, `managed-mcp.json`)                              |
| [`features/plugins.md`](features/plugins.md)     | Plugin layout, marketplaces, lifecycle                                            |
| [`features/general.md`](features/general.md)     | Cross-cutting: total context budget, layering hazards, the four diagnostics ask  |

### Reference & deep dives

Longer-form companion guides. They predate the per-feature pages above and go wider (whole-machine
structure, command/evaluator catalogues, the `AGENTS.md` standard); the feature pages are the
quick, vertical reference.

| Page                                                               | Covers                                                                                                |
| ------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| [`claude-project-configuration.md`](claude-project-configuration.md) | Configuring Claude Code for a single repository — the project-scoped slice, end to end                |
| [`claude-config-best-practices.md`](claude-config-best-practices.md) | Per-entity Must / Should hygiene to keep the harness fast, cheap, and predictable                     |
| [`claude-config-commands.md`](claude-config-commands.md)           | Every built-in command (and bundled skill) that creates / edits / improves a config entity            |
| [`claude-evaluators.md`](claude-evaluators.md)                     | Everything that evaluates, audits, scores, or recommends — grouped by what it acts on                 |
| [`claude-agents-mapping.md`](claude-agents-mapping.md)             | Claude Code ↔ the `AGENTS.md` open standard — feature mapping (import / symlink, behavioral equivalence) |
| [`agents-md-structure.md`](agents-md-structure.md)                 | The `AGENTS.md` open standard itself — what it is and how it's structured                             |

## Sources

- Extend Claude Code — <https://code.claude.com/docs/en/features-overview> · Overview — <https://code.claude.com/docs/en/overview>
- Settings — <https://code.claude.com/docs/en/settings> · Memory — <https://code.claude.com/docs/en/memory> · Subagents — <https://code.claude.com/docs/en/sub-agents>
- Skills — <https://code.claude.com/docs/en/skills> · Hooks — <https://code.claude.com/docs/en/hooks> · MCP — <https://code.claude.com/docs/en/mcp> · Plugins — <https://code.claude.com/docs/en/plugins> · Commands — <https://code.claude.com/docs/en/commands>
- AGENTS.md open standard — <https://agents.md>
