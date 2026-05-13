# Skills calibration reference

> Source of truth: [`docs/features/skills.md`](../../docs/features/skills.md).

## Must

- `name` and `description` set in frontmatter.
- `description` + `when_to_use` combined ≤ 1,536 chars (Claude's routing budget).
- `name` ≤ 64 chars (hard cap).
- Side-effecting skills (deploy / commit / publish / release / delete) have
  `disable-model-invocation: true`.

## Should

- `description` includes routing cues ("use when …", "after …", "before …").
- `allowed-tools` narrowly scoped — `Bash(gh *)` not bare `Bash`; `Edit(.claude/**)` not bare
  `Edit`.
- Body ≤ ~500 lines; reference detail in `reference.md`.
- A skill that shells out heavily to a CLI (gh, kubectl, gcloud, aws, pnpm, docker, terraform,
  helm) should be a 4-layer wrapper with a scoped `Bash(<tool> *)` permission.
- One skill per workflow; avoid overlapping descriptions (Claude routes by description).

## Limits

| Aspect | Recommended |
|---|---|
| `name` | ≤ 64 chars |
| `description` + `when_to_use` | ≤ 1,536 chars |
| Body | ≤ ~500 lines |
| `allowed-tools` | scoped form `Tool(arg *)` |

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `skill:missing-name` | No `name` in frontmatter | HIGH |
| `skill:missing-description` | No `description` in frontmatter | HIGH |
| `skill:description-over-1536` | `description` + `when_to_use` combined > 1,536 chars | MEDIUM |
| `skill:vague-description` | Description lacks key use-case keywords (Claude can't route on it) | MEDIUM |
| `skill:body-over-500` | `SKILL.md` body over 500 lines | MEDIUM |
| `skill:side-effecting-no-dmi` | Body uses side-effecting verbs (deploy/commit/push/publish/release/delete/post) but no `disable-model-invocation: true` | HIGH |
| `skill:overlap` | Two skills' descriptions match overlapping triggers | MEDIUM |
| `skill:allowed-tools-broad` | `allowed-tools` includes bare `Bash` / `Edit` / `Write` where a narrow rule would suffice | LOW |
| `skill:name-over-64` | `name` longer than 64 chars (hard cap) | HIGH |
| `skill:cli-not-wrapped` | Body shells out to a known CLI without a scoped `Bash(<tool> *)` `allowed-tools` | LOW |
| `skill:in-repo-only-ok` | Skill only does in-repo file ops — correctly 3-layer (anti-signature) | INFO |
