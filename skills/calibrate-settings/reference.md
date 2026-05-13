# Settings calibration reference

> Source of truth: [`docs/features/settings.md`](../../docs/features/settings.md).

## Must

- No secrets in committed `settings.json`. Machine-specific values + personal tweaks → `.local.json`
  (gitignored).
- Never run with `--dangerously-skip-permissions`. Build a real `permissions` allowlist instead.
- Know the precedence chain (managed → CLI args → local → project → user) before debugging.

## Should

- Tighten `permissions`: allowlist the safe-and-frequent (`/fewer-permission-prompts` drafts from
  transcripts); never blanket-allow destructive operations; use rule syntax (`Bash(git *)`,
  `Edit(*.ts)`) over broad allows.
- Keep `env` minimal — only what's genuinely needed every session.
- Don't pin a `model` in committed settings unless the team agrees; route per task. Use
  `availableModels` to constrain the menu instead of hard-pinning.
- Set a sane `cleanupPeriodDays` so transcript/state growth stays bounded.
- `claudeMdExcludes` in monorepos to skip other teams' ancestor `CLAUDE.md`; `skillOverrides` to
  demote noisy third-party skills (`"name-only"` / `"off"`) without editing their files.
- For org-wide enforcement use *managed* settings (`permissions.deny`, `sandbox.enabled`, `env`,
  `forceLoginMethod`) — those are technically enforced; managed `CLAUDE.md` is only guidance.

## Pattern signatures

| Signature | Trigger | Default severity |
|---|---|---|
| `settings:secret-in-committed` | A `settings.json` (not `.local`) contains an obvious secret value | **CRITICAL** |
| `settings:dangerously-skip-permissions` | Any reference to `dangerously-skip-permissions` in any settings layer or referenced script | **CRITICAL** |
| `settings:permissions-blanket-destructive` | `permissions.allow` includes `Bash(*)` or `Bash(rm *)` or similar broadly destructive entries | HIGH |
| `settings:model-pinned-in-committed` | `model:` set in a committed (non-`.local`) settings file | LOW |
| `settings:env-bloated` | `env` block has > ~10 entries | LOW |
| `settings:permissions-empty` | No `permissions.allow` entries — every prompt is approved manually | LOW |
| `settings:invalid-json` | The file isn't valid JSON | HIGH |
| `settings:precedence-surprise` | A project value is overridden by managed (note for the user) | LOW |
