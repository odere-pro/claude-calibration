# Skills calibration reference

> Source of truth: [`docs/features/skills.md`](../../docs/features/skills.md). This file is the
> calibration rubric — kept in sync by `/plugin-update`. The evaluator reads *this* file (not the doc)
> when scoring skills.

## Must

- Combined `description` + `when_to_use` is **truncated at 1,536 chars** in the skill listing — keep
  it well under that, key use case first. Vague descriptions never fire (or fire wrongly).
- One skill = one capability. Overlapping skills compete for routing — split or merge, don't duplicate.
- No secrets in `SKILL.md` or supporting files (skills are committed; review project skills before
  trusting a repo, since `allowed-tools` can grant broad access).

## Should

- `SKILL.md` body **under ~500 lines** (loaded for the rest of the session once invoked, so every line
  is a recurring cost). Concise even then; state *what to do*, not *how/why*.
- Body structure: `# Title` → 1-paragraph overview → instructions → "Additional resources" links to
  `reference.md` / `examples.md` / `scripts/`.
- `disable-model-invocation: true` on side-effecting workflows (`/deploy`, `/commit`, `/post-to-slack`,
  anything that edits config). Drops description cost to **zero**; Claude can never auto-fire it.
- `allowed-tools` narrow — only tools genuinely needed without a prompt. Scope `Bash` to specific
  commands (`Bash(git diff:*)`, not bare `Bash`).
- `paths:` to scope auto-activation when the skill is feature-specific.
- `context: fork` for heavy isolated tasks (research, scans).
- One capability per skill; consolidate near-duplicates.
- Pruning: `skillOverrides` `"off"`/`"name-only"`, or delete; check with `/skills` (token sort).

## Limits

| Field | Recommended | Hard cap |
|---|---|---|
| `name` | lowercase letters/numbers/hyphens; ≤ 64 chars | 64 |
| `description` (+ `when_to_use`, combined) | well under 1,536; key use case first | 1,536 |
| `SKILL.md` body | ≤ ~500 lines | none |
| Per-skill on `/compact` re-attach | first ~5,000 tokens; 25,000-token combined budget | hard |

## Pattern signatures (recurrence detector keys on these)

| Signature | Trigger | Default severity |
|---|---|---|
| `skill:missing-description` | No `description` in frontmatter | HIGH |
| `skill:description-over-1536` | `description` + `when_to_use` combined > 1,536 chars | MEDIUM |
| `skill:vague-description` | Description lacks key use-case keywords (Claude can't route on it) | MEDIUM |
| `skill:body-over-500` | `SKILL.md` body over 500 lines | MEDIUM |
| `skill:side-effecting-no-dmi` | Body uses side-effecting verbs (deploy/commit/push/publish/release/delete/post) but no `disable-model-invocation: true` | HIGH |
| `skill:overlap` | Two skills' descriptions match overlapping triggers (substring/keyword overlap heuristic) | MEDIUM |
| `skill:allowed-tools-broad` | `allowed-tools` includes bare `Bash` / `Edit` / `Write` where a narrow rule would suffice | LOW |
| `skill:name-over-64` | `name` longer than 64 chars (hard cap) | HIGH |
| `skill:cli-not-wrapped` | Body shells out to a known CLI (`gh`, `kubectl`, `aws`, `pnpm`, `gcloud`, `docker`, `terraform`) repeatedly without wrapping → 3-layer where 4-layer is warranted | LOW |
| `skill:in-repo-only-ok` | Skill only does in-repo file ops with no external touch — correctly 3-layer; *don't* push to 4-layer | INFO |

CRITICAL is reserved for committed-secret findings (the *content* check, not a structural one).

## 3-vs-4-layer call (skills specifically)

A skill is **3-layer** when its work is performed by Claude with built-in tools (Read/Edit/Write/Glob/
Grep) ± in-repo `scripts/`. A skill is **4-layer** when its primary job is to wrap an external CLI
or MCP server, making it useful to Claude (recipe library, schema docs, common-query patterns).

Tell them apart:

- **4-layer signal:** `allowed-tools` cites `Bash(<tool> *)`; the body's examples almost all invoke
  the same external command; the skill pairs with an MCP server name in `.mcp.json`.
- **3-layer is right for:** refactor patterns, code-style fixes, doc/spec generation, config audits,
  in-repo workflow.
- **Promote 3 → 4** (via `templates/cli-wrapper.tmpl` or `templates/mcp-wrapper.tmpl`) when the same
  external CLI/MCP recurs across the setup or a server has no skill pair.
- **Don't promote** when the skill is genuinely in-repo only — a wrapper would be ceremony.
