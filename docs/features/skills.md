# Skills

`.claude/skills/<name>/SKILL.md` — model-invocable or user-invocable bundles of instructions and
scripts. The current form of "custom commands"; legacy `.claude/commands/*.md` is still supported.

## Definition

- **Files** — one directory per skill, each containing `SKILL.md` plus optional `scripts/`,
  `templates/`, `examples/`, `reference.md`.
- **Frontmatter** — `name`, `description`, `argument-hint`, `disable-model-invocation`, `model`,
  `allowed-tools`.
- **What it does** — packages a recurring workflow; Claude can invoke it by name (or, if not
  `disable-model-invocation: true`, auto-fire it when the description matches).

## Scope

User · Project · Plugin-shipped. Plugin skills appear under `/<plugin-name>:<skill-name>`.

## Configure

- `description` + `when_to_use` combined ≤ 1,536 chars (Claude's routing budget).
- Body ≤ ~500 lines; reference material belongs in `reference.md`.
- `disable-model-invocation: true` removes the skill from Claude's standing context — zero cost
  when idle.
- Use `allowed-tools` narrowly (`Bash(git diff:*)`, not bare `Bash`).
- **3 vs 4 layers** — a skill that shells out heavily to a CLI (gh, kubectl, gcloud) without a
  scoped `Bash(<tool> *)` permission is the 3-layer anti-pattern; promote to a 4-layer wrapper.

## Validate

- `/skills` (press `t` to sort by token cost).
- `bash skills/calibrate-skills/scripts/lint.sh <SKILL.md>` — `skill:missing-name`,
  `:missing-description`, `:description-over-1536`, `:vague-description`, `:body-over-500`,
  `:side-effecting-no-dmi`, `:overlap`, `:allowed-tools-broad`, `:name-over-64`,
  `:cli-not-wrapped`, `:in-repo-only-ok`.

## Improve

| Must                                              | Should                                            | Limit                          |
| ------------------------------------------------- | ------------------------------------------------- | ------------------------------ |
| `name`, `description` present                     | Use `disable-model-invocation` for side-effecting | description ≤ 1,536 chars      |
| Side-effecting skills must disable model invoke   | Narrow `allowed-tools`                            | body ≤ ~500 lines              |
| `name` ≤ 64 chars                                 | Wrap heavy CLI usage (3→4 layer promotion)        |                                |

## Sources

- Skills — <https://code.claude.com/docs/en/skills>
- Commands — <https://code.claude.com/docs/en/commands>
