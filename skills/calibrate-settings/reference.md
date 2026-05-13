# Settings calibration reference

> Source of truth: [`docs/features/settings.md`](../../docs/features/settings.md).

## Must

- No secrets in a committed `settings.json` — secrets belong in `.local.json` (git-ignored) or in
  an `${ENV_VAR}` reference.
- No `--dangerously-skip-permissions` in any settings layer or any script the settings reference.
- Valid JSON.

## Should

- Narrow `permissions.allow` entries (`Bash(git status:*)`, `Bash(ls:*)`) — no `Bash(*)`,
  `Bash(rm *)`, `Bash(sudo *)`.
- Move per-machine `env` overrides and `model:` pins out of the committed file into `.local.json`.
- Keep `env` minimal — committed `env` is read by every contributor; bloat is a smell.
- Populate `permissions.allow` with the baseline safe set; empty means every prompt requires manual
  approval and degrades the experience for everyone on the project.

## Limits

| Aspect            | Recommended                                           |
| ----------------- | ----------------------------------------------------- |
| `env` size        | ≤ ~10 entries in the committed file                   |
| `permissions.allow` entries | narrow tool patterns only; no `Bash(*)` blanket |
| Model pin         | only in `.local.json` (per-machine), not committed    |

## Pattern signatures

| Signature                                  | Trigger                                                                                       | Default severity |
| ------------------------------------------ | --------------------------------------------------------------------------------------------- | ---------------- |
| `settings:secret-in-committed`             | A `settings.json` (not `.local`) contains an obvious secret value                             | **CRITICAL**     |
| `settings:dangerously-skip-permissions`    | Any reference to `dangerously-skip-permissions` in any settings layer or referenced script    | **CRITICAL**     |
| `settings:permissions-blanket-destructive` | `permissions.allow` includes `Bash(*)` or `Bash(rm *)` or similarly destructive entries       | HIGH             |
| `settings:invalid-json`                    | The file isn't valid JSON                                                                     | HIGH             |
| `settings:model-pinned-in-committed`       | `model:` set in a committed (non-`.local`) settings file                                      | LOW              |
| `settings:env-bloated`                     | `env` block has > ~10 entries                                                                 | LOW              |
| `settings:permissions-empty`               | No `permissions.allow` entries — every prompt approved manually                               | LOW              |
| `settings:precedence-surprise`             | A project value is silently overridden by managed                                             | LOW              |
