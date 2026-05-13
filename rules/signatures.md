---
name: signatures
description: >-
  The canonical pattern-signature catalogue for the calibration plugin. Loads only when you have a
  calibration run folder or one of the per-feature bundle directories open. Used by the planner's
  recurrence detector and by the evaluator when it tabulates findings — keeps signature names
  consistent across runs (a typo'd signature breaks recurrence grouping).
paths:
  - ".claude/calibration/**"
  - "skills/calibrate-*/**"
  - "skills/calibration-*/**"
  - "agents/calibration-*.md"
---

# Pattern signatures — calibration plugin

Every finding emitted by a `calibrate-<feature>` bundle's `lint.sh` carries a **pattern signature**
in the form `<feature>:<short-name>`. The planner's recurrence detector groups findings by
signature; a signature firing ≥3× in this run or ≥2× across older runs is a recurrence and is
eligible for a `kind: create` enforcement row. **Signature names are part of the public contract** —
if you rename one, the recurrence history breaks.

## Why signatures matter

- **Recurrence detection** (planner step 2) keys on the literal signature string. Group findings by
  signature; promote repeats. A typo (`subagent:missing-tool` vs `subagent:missing-tools`) means
  the recurrence is invisible to the planner.
- **Cross-run tracking** (planner reads older `eval-*` files) requires stable signatures over time.
  Renames need a migration path or older runs become unreadable.
- **Bundle dispatch** (calibrator step 2) maps each signature to a bundle via the rules in
  [`dispatch.md`](dispatch.md). Inconsistent signature names break the routing.

## Catalogue (by bundle)

Each row: `signature · default severity · what it flags`.

### `calibrate-claude-md`

| Signature                          | Sev      | Trigger                                                                                 |
| ---------------------------------- | -------- | --------------------------------------------------------------------------------------- | ------- | ---------- | -------- | --------------- | -------------------------------------------------------- |
| `claude-md:secret-leak`            | CRITICAL | Any `\*KEY                                                                              | \*TOKEN | \*PASSWORD | \*SECRET | sk-[a-zA-Z0-9]+ | api[_-]?key\s\*=` pattern in CLAUDE.md / CLAUDE.local.md |
| `claude-md:over-200`               | MEDIUM   | File > 200 lines                                                                        |
| `claude-md:over-400`               | HIGH     | File > 400 lines                                                                        |
| `claude-md:vague-rules`            | MEDIUM   | Aspirational verbs without specifics ("test your changes", "format code", "be careful") |
| `claude-md:no-agents-md-import`    | LOW      | `AGENTS.md` exists in the same dir but no `@AGENTS.md` (or symlink) in CLAUDE.md        |
| `claude-md:imports-too-deep`       | HIGH     | `@`-import chain > 5 hops                                                               |
| `claude-md:contradicts-nested`     | MEDIUM   | Two CLAUDE.md files at different levels state contradictory rules on the same topic     |
| `claude-md:must-rule-with-no-hook` | MEDIUM   | Body says "always do X" / "never do Y" — should be a hook, not a request                |
| `claude-md:restated-readme`        | LOW      | Body restates README content rather than linking to it                                  |

### `calibrate-rules`

| Signature | Sev | Trigger |
|---|---|---|
| `rule:secret-leak` | CRITICAL | Same patterns as `claude-md:secret-leak` |
| `rule:over-200` | MEDIUM | Effective lines > 200 |
| `rule:no-paths-when-language-specific` | MEDIUM | Filename / content suggests a specific language or dir (`testing-typescript.md`, body cites `*.ts` patterns) but no `paths:` frontmatter |
| `rule:plugin-shipped-no-paths` | HIGH | Rule sits under a plugin's `rules/` (`.claude-plugin/plugin.json` in the same plugin root) but has no `paths:` frontmatter — loads always-on for every user who enables the plugin |
| `rule:bad-glob` | HIGH | `paths:` frontmatter doesn't parse as a YAML list of strings, or contains an obviously broken glob |
| `rule:contradicts-claude-md` | LOW | A rule restates a topic CLAUDE.md already covers (overlap heuristic) |
| `rule:should-be-skill` | LOW | Rule body describes a multi-step workflow rather than always-on guidance |

### `calibrate-settings`

| Signature                                  | Sev      | Trigger                                                                                    |
| ------------------------------------------ | -------- | ------------------------------------------------------------------------------------------ |
| `settings:secret-in-committed`             | CRITICAL | A `settings.json` (not `.local`) contains an obvious secret value                          |
| `settings:dangerously-skip-permissions`    | CRITICAL | Any reference to `dangerously-skip-permissions` in any settings layer or referenced script |
| `settings:permissions-blanket-destructive` | HIGH     | `permissions.allow` includes `Bash(*)` or `Bash(rm *)` or similarly destructive entries    |
| `settings:model-pinned-in-committed`       | LOW      | `model:` set in a committed (non-`.local`) settings file                                   |
| `settings:env-bloated`                     | LOW      | `env` block has > ~10 entries                                                              |
| `settings:permissions-empty`               | LOW      | No `permissions.allow` entries — every prompt approved manually                            |
| `settings:invalid-json`                    | HIGH     | The file isn't valid JSON                                                                  |
| `settings:precedence-surprise`             | LOW      | A project value is overridden by managed                                                   |

### `calibrate-skills`

| Signature                     | Sev    | Trigger                                                                                                                                                                                    |
| ----------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `skill:missing-name`          | HIGH   | No `name` in frontmatter                                                                                                                                                                   |
| `skill:missing-description`   | HIGH   | No `description` in frontmatter                                                                                                                                                            |
| `skill:description-over-1536` | MEDIUM | `description` + `when_to_use` combined > 1,536 chars                                                                                                                                       |
| `skill:vague-description`     | MEDIUM | Description lacks key use-case keywords (Claude can't route on it)                                                                                                                         |
| `skill:body-over-500`         | MEDIUM | `SKILL.md` body over 500 lines                                                                                                                                                             |
| `skill:side-effecting-no-dmi` | HIGH   | Body uses side-effecting verbs (deploy/commit/push/publish/release/delete/post) but no `disable-model-invocation: true`                                                                    |
| `skill:overlap`               | MEDIUM | Two skills' descriptions match overlapping triggers                                                                                                                                        |
| `skill:allowed-tools-broad`   | LOW    | `allowed-tools` includes bare `Bash` / `Edit` / `Write` where a narrow rule would suffice                                                                                                  |
| `skill:name-over-64`          | HIGH   | `name` longer than 64 chars (hard cap)                                                                                                                                                     |
| `skill:cli-not-wrapped`       | LOW    | Body shells out to a known CLI (`gh`, `kubectl`, `aws`, `pnpm`, `gcloud`, `docker`, `terraform`, `helm`) without a scoped `Bash(<tool> *)` `allowed-tools` — 3→4-layer promotion candidate |
| `skill:in-repo-only-ok`       | INFO   | Skill only does in-repo file ops — correctly 3-layer (anti-signature; prevents wrong-direction promotion)                                                                                  |

### `calibrate-subagents`

| Signature                             | Sev    | Trigger                                                                                  |
| ------------------------------------- | ------ | ---------------------------------------------------------------------------------------- |
| `subagent:missing-name`               | HIGH   | No `name` in frontmatter                                                                 |
| `subagent:missing-description`        | HIGH   | No `description` in frontmatter                                                          |
| `subagent:missing-tools`              | HIGH   | `tools:` omitted → inherits ALL tools incl. MCP                                          |
| `subagent:body-over-200`              | MEDIUM | Body > 200 lines                                                                         |
| `subagent:default-inherit-model`      | MEDIUM | `model:` omitted (defaults to `inherit`)                                                 |
| `subagent:vague-description`          | MEDIUM | Description lacks routing cues / trigger keywords                                        |
| `subagent:near-duplicate`             | MEDIUM | Two agents' descriptions overlap heavily (consolidation candidate)                       |
| `subagent:bare-mcp-in-mcpjson`        | LOW    | Subagent uses an MCP server defined in `.mcp.json` that no other agent uses              |
| `subagent:plugin-ignored-frontmatter` | LOW    | Plugin-shipped subagent has `hooks` / `mcpServers` / `permissionMode` (silently ignored) |

### `calibrate-hooks`

| Signature                            | Sev    | Trigger                                                                                             |
| ------------------------------------ | ------ | --------------------------------------------------------------------------------------------------- |
| `hook:matcher-bare-star`             | MEDIUM | `matcher: "*"` (or `""`/omitted) on a hot event (`PreToolUse` / `PostToolUse` / `UserPromptSubmit`) |
| `hook:exit-1-non-blocking`           | HIGH   | Hook script uses `exit 1` for what looks like enforcement (preceded by `BLOCKED`/`error` echo)      |
| `hook:remote-untrusted`              | HIGH   | Hook command contains `curl`/`wget`/`npx ` followed by a URL or remote package                      |
| `hook:duplicate-across-layers`       | LOW    | Same `(event, matcher, command)` defined in both user and project                                   |
| `hook:not-locally-sourced`           | LOW    | Hook command references a binary not in `${CLAUDE_PROJECT_DIR}` and not a known system tool         |
| `hook:heavy-on-pretooluse-heuristic` | MEDIUM | `PreToolUse`/`PostToolUse` hook command includes `build`/`test`/`compile`/`tsc`/`webpack` keywords  |
| `hook:invalid-json`                  | HIGH   | Settings `hooks` block doesn't parse                                                                |

### `calibrate-mcp`

| Signature                     | Sev      | Trigger                                                                                                           |
| ----------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------- |
| `mcp:secret-in-mcpjson`       | CRITICAL | A literal token-shaped string in `.mcp.json` (or in a committed `mcpServers` block)                               |
| `mcp:no-skill-pair`           | LOW      | A server in `.mcp.json` whose name has no matching skill                                                          |
| `mcp:over-broad-surface`      | MEDIUM   | A server with a high known tool count (heuristic: 50+ if metadata available)                                      |
| `mcp:dead-server-heuristic`   | LOW      | A server in config that hasn't appeared in `~/.claude/projects/*/transcripts/*.jsonl` for ≥ 30 days (best-effort) |
| `mcp:subagent-only-in-shared` | LOW      | A server appears used by exactly one subagent's body — should move to that agent's `mcpServers:` frontmatter      |
| `mcp:invalid-json`            | HIGH     | The file isn't valid JSON                                                                                         |

### `calibrate-plugins`

| Signature                           | Sev  | Trigger                                                                                       |
| ----------------------------------- | ---- | --------------------------------------------------------------------------------------------- |
| `plugin:missing-version`            | LOW  | `.claude-plugin/plugin.json` lacks `version`                                                  |
| `plugin:missing-name`               | HIGH | manifest lacks `name`                                                                         |
| `plugin:misplaced-components`       | HIGH | `skills/` / `agents/` / `hooks/` etc. found _inside_ `.claude-plugin/` instead of plugin root |
| `plugin:legacy-commands-only`       | LOW  | plugin has `commands/` but no `skills/`                                                       |
| `plugin:enabled-not-used-heuristic` | LOW  | enabled in `installed_plugins.json` but not referenced in recent transcripts (best-effort)    |
| `plugin:duplicate-marketplaces`     | LOW  | the same marketplace registered twice                                                         |
| `plugin:invalid-manifest-json`      | HIGH | manifest doesn't parse                                                                        |

### `calibrate-general`

| Signature                               | Sev    | Trigger                                                                                               |
| --------------------------------------- | ------ | ----------------------------------------------------------------------------------------------------- |
| `general:context-budget-overflow`       | MEDIUM | Estimated total always-on cost > a heuristic threshold (e.g. > 5,000 tokens)                          |
| `general:nested-claude-md-conflict`     | LOW    | ≥ 3 nested CLAUDE.md files (conflict-risk indicator)                                                  |
| `general:settings-precedence-surprise`  | LOW    | A project setting is silently overridden by a managed setting                                         |
| `general:no-gitignore-for-claude-local` | LOW    | `.gitignore` doesn't cover `CLAUDE.local.md` / `.claude/settings.local.json` / `.claude/calibration/` |
| `general:must-rule-with-no-hook`        | MEDIUM | CLAUDE.md or rules contain "must"/"always"/"never" lines but no hooks block exists                    |
| `general:diagnostics-ask`               | INFO   | (Always emitted) Reminder that the four CLI outputs should be pasted into the report                  |

## Severity scale (use these literal values)

- **CRITICAL** — secret in a committed file; `--dangerously-skip-permissions`; destructive op
  blanket-allowed; data-loss risk.
- **HIGH** — a Must fail; a real bug/quality problem; serious context bloat.
- **MEDIUM** — a maintainability problem; an over-limit value with real cost; a missed Should that
  matters.
- **LOW** — style, minor, or speculative.
- **INFO** — pure annotation; no action implied.

## Naming convention

- Lowercase only. Use `-` between words (`missing-tools`, not `missing_tools`).
- Prefix with the feature (`claude-md`, `rule`, `settings`, `skill`, `subagent`, `hook`, `mcp`,
  `plugin`, `general`). The bundle that owns the signature owns the lint that emits it.
- Numeric thresholds embedded in the name (`over-200`, `over-1536`, `over-400`) — when the threshold
  changes, the signature changes. Older runs keep their old signature; the planner's cross-run
  recurrence matcher should treat `over-N` and `over-M` as the same family.
- Use `:no-X` for "missing X" (e.g. `no-paths-when-language-specific`, `no-skill-pair`,
  `no-gitignore-for-claude-local`) — easier to scan.

## When a new signature is needed

1. Add the row here first (severity + trigger + bundle).
2. Add the same row to the owning bundle's `reference.md`.
3. Emit the signature from the bundle's `scripts/lint.sh`.
4. Map it in [`dispatch.md`](dispatch.md) if it has a `kind: create` archetype (recurrence target).

`/plugin-update` keeps `reference.md` / `lint.sh` constants in sync with the source `docs/features/*.md`;
this rules file is the authoritative cross-bundle catalogue — keep it the same shape as the
per-bundle tables so they read in parallel.
