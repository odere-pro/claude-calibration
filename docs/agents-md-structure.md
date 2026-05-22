[← README](README.md) · [Claude ↔ AGENTS.md](claude-agents-mapping.md) · [Glossary](glossary.md)

# `AGENTS.md` — the Open Standard

`AGENTS.md` is a vendor-neutral, open convention for giving AI coding agents the context and
instructions they need to work in a repository. Think of it as a **README for agents**: the
human-facing `README.md` stays focused on people, while `AGENTS.md` holds the build steps,
conventions, gotchas, and guardrails an agent needs.

Reference: <https://agents.md>

---

## Why it exists

- One instruction file that every agent reads, instead of a different bespoke file per tool.
- A wide and growing set of tools read it: OpenAI Codex / Codex CLI, Google Jules, Google
  Gemini CLI, Cursor, Aider, goose, opencode, Zed, Warp, VS Code (Copilot), GitHub Copilot,
  Devin, JetBrains Junie, Amp, RooCode, Kilo Code, Phoenix, Semgrep, Windsurf, Augment Code,
  Ona, UiPath, Factory, and others ([full list](https://agents.md)).
- It's just Markdown — no schema, no required fields, no build step.

### Claude Code and `AGENTS.md`

**Claude Code reads `CLAUDE.md`, not `AGENTS.md`.** To use the open-standard file with Claude
Code, bridge it from `CLAUDE.md` — either import it:

```markdown
@AGENTS.md

## Claude Code
Claude-specific instructions can go here, below the import.
```

…or symlink (when you don't need Claude-specific additions):

```bash
ln -s AGENTS.md CLAUDE.md
```

On Windows a symlink needs Administrator privileges or Developer Mode, so prefer the `@AGENTS.md`
import there. Running `/init` in a repo that already has `AGENTS.md` reads it (along with
`.cursorrules`, `.windsurfrules`, etc.) and folds the relevant parts into the generated
`CLAUDE.md`. Sources: [Claude Code memory docs](https://code.claude.com/docs/en/memory#agents-md).

---

## File format

- **Plain Markdown.** "AGENTS.md is just standard Markdown. Use any headings you like; the agent
  simply parses the text you provide." No required schema.
- **Location:** the repo root for the project-wide file. In a monorepo, additional `AGENTS.md`
  files can live in subdirectories/packages — agents "automatically read the nearest file in the
  directory tree, so the closest one takes precedence and every subproject can ship tailored
  instructions."
- **Precedence vs. a direct prompt:** "explicit user chat prompts override everything."
- **Programmatic checks still apply:** if `AGENTS.md` says "run `pnpm test` before committing",
  agents are expected to actually run it, not just acknowledge it.

There is no official linter or schema. Keep it short, concrete, and current — stale instructions
are worse than none.

---

## Recommended structure

A pragmatic template. Use the sections that apply; delete the rest.

```markdown
# <Project Name>

## Project overview
One or two paragraphs: what this repo is, the stack, the architecture in a sentence,
where the important code lives.

## Setup & environment
- Prerequisites (language/runtime versions, package manager, system deps)
- Bootstrap: `<install command>`
- Required env vars / where to get them (never put secrets here — point at a vault or `.env.example`)

## Build & run
- Dev server: `<command>`
- Production build: `<command>`
- Common scripts and what they do

## Testing
- Run the full suite: `<command>`
- Run a single test / package: `<command>`
- Coverage expectations, where tests live, naming conventions
- "Always run X before opening a PR."

## Code style & conventions
- Formatter / linter and how to run them (`<command>`)
- Naming, file organization, import ordering
- Patterns to follow; anti-patterns to avoid
- Link to deeper docs rather than inlining everything

## Project layout
- `src/...` — ...
- `packages/...` — ... (note any nested AGENTS.md)
- Generated files / things not to hand-edit

## Git & PR guidelines
- Branch naming, commit message format (e.g. Conventional Commits)
- Required checks before pushing
- PR description template / what reviewers expect

## Security & safety
- Secrets handling, what must never be committed
- Files/dirs that are off-limits or require extra care
- Commands that are destructive or need confirmation

## Gotchas / institutional knowledge
- Flaky tests, slow steps, known-broken things
- Non-obvious decisions a newcomer (or agent) would trip on
```

### Monorepo layout

```text
repo/
├── AGENTS.md                 # repo-wide defaults  (CLAUDE.md -> AGENTS.md symlink, or CLAUDE.md with @AGENTS.md)
├── apps/
│   ├── web/
│   │   └── AGENTS.md         # overrides/extends for the web app
│   └── api/
│       └── AGENTS.md         # overrides/extends for the API
└── packages/
    └── ui/
        └── AGENTS.md         # overrides/extends for the UI package
```

An agent editing `apps/web/src/Foo.tsx` reads `apps/web/AGENTS.md` (nearest), falling back to the
root file for anything not specified there.

---

## Relationship to other files

| File | Audience | Notes |
|------|----------|-------|
| `README.md` | Humans | "README.md files are for humans: quick starts, project descriptions, and contribution guidelines." Link to it from `AGENTS.md` instead of duplicating. |
| `AGENTS.md` | Agents (any vendor) | The portable standard — "the extra, sometimes detailed context coding agents need." |
| `CLAUDE.md` | Claude Code | Claude Code reads **this**, not `AGENTS.md`. Bridge with `@AGENTS.md` or `ln -s AGENTS.md CLAUDE.md` to keep one source of truth. |
| `~/.claude/rules/**`, `.claude/rules/**` | Claude Code | Modular rule files auto-loaded by Claude Code (optionally path-scoped via `paths:` frontmatter), and also `@`-includable from `CLAUDE.md`. See [memory docs](https://code.claude.com/docs/en/memory#organize-rules-with-claude-rules). |

---

## Do / don't

**Do**
- Keep it concise and skimmable; agents (and people) read top-to-bottom.
- Put exact commands in backticks so they can be run verbatim.
- Update it in the same PR that changes the workflow it describes.
- Use nested files in monorepos rather than one giant root file.

**Don't**
- Don't put secrets, tokens, or internal URLs in it — point at `.env.example` or a secret manager.
- Don't restate the whole README; link instead.
- Don't write aspirational rules you don't actually enforce — agents will follow them literally.
- Don't let it rot. A wrong instruction is actively harmful.

---

## Sources

- AGENTS.md open standard — <https://agents.md>
- Claude Code, *How Claude remembers your project* (the `AGENTS.md` section, `@path` imports,
  `.claude/rules/`) — <https://code.claude.com/docs/en/memory>
- See also `claude-agents-mapping.md` (this repo) for the Claude Code ↔ open-standard mapping.
