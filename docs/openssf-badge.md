[← README](README.md) · [Security policy](../SECURITY.md) · [Contributing](../CONTRIBUTING.md) · [Gate map](../CLAUDE.md)

# OpenSSF Best Practices Badge — passing-level self-assessment

A row-by-row self-assessment of `claude-calibration` against the [OpenSSF Best Practices
Badge](https://www.bestpractices.dev/) **passing** criteria. Every criterion is either **Met** or
**N/A**; the few that rest on a maintainer activity claim rather than a file are flagged
*(attest)* and listed under [Maintainer attestations](#maintainer-attestations).

- **Project:** `claude-calibration` — a Claude Code **plugin** (skills, agents, rules, hooks, docs,
  JSON manifests + a few Bash scripts). See [`README.md`](../README.md).
- **Languages:** Shell (Bash), Markdown, JSON. There is no compiled code.
- **License:** MIT — [`LICENSE`](../LICENSE), declared again in `.claude-plugin/plugin.json`.
- **Regenerate this assessment:** re-run `bash tests/gates/run-all.sh` and
  `bash tests/eval/run-eval.sh`, and re-read the four workflows under `.github/workflows/`
  (`ci.yml`, `codeql.yml`, `scorecard.yml`, `release.yml`). The facts below derive entirely from
  files in this repository.

This is a docs-only record. The badge is shown in [`README.md`](../README.md) and links to the
[BadgeApp project entry](https://www.bestpractices.dev/projects/12996) (separate from the existing
OpenSSF Scorecard badge).

## Basics

| Criterion | Answer | Evidence |
| --- | --- | --- |
| `description_good` | Met | One-line description in [`README.md`](../README.md) and `.claude-plugin/plugin.json`. |
| `interact` | Met | GitHub Issues with bug/feature templates; channels in [`CONTRIBUTING.md`](../CONTRIBUTING.md). |
| `contribution` | Met | [`CONTRIBUTING.md`](../CONTRIBUTING.md) — dev loop, gates, signature contract, bundle layout, branches/commits, releasing. |
| `contribution_requirements` | Met | [`CONTRIBUTING.md`](../CONTRIBUTING.md) + `.github/pull_request_template.md`: Conventional Commits, branch naming, changelog fragment, gates green. |
| `floss_license` | Met | MIT — [`LICENSE`](../LICENSE); `plugin.json` `"license": "MIT"`. |
| `floss_license_osi` | Met | MIT is OSI-approved. |
| `license_location` | Met | [`LICENSE`](../LICENSE) at repo root; declared in `plugin.json` + README badge. |
| `documentation_basics` | Met | [`README.md`](../README.md) + the [docs index](README.md), [`install.md`](install.md), [`usage.md`](usage.md), [`glossary.md`](glossary.md). |
| `documentation_interface` | Met | [`usage.md`](usage.md) (commands/flows) + the nine `features/*.md` pages + [`glossary.md`](glossary.md). |
| `sites_https` | Met | GitHub repo HTTPS-only; all manifest URLs are https. |
| `discussion` | Met | GitHub Issues. |
| `english` | Met | All docs in English. |
| `maintained` | Met | Active — v0.1.0 (2026-05-22), v0.1.1 (2026-05-26); see [`CHANGELOG.md`](../CHANGELOG.md). |

## Change control

| Criterion | Answer | Evidence |
| --- | --- | --- |
| `repo_public` | Met | Public GitHub repository. |
| `repo_track` | Met | Full git history (author/committer/timestamp per change). |
| `repo_interim` | Met | Feature branches + PRs; `main` requires a PR plus a green "validation gates" CI run before merge. |
| `repo_distributed` | Met | git. |
| `version_unique` | Met | `.claude-plugin/plugin.json` version + git tags `v0.1.0` / `v0.1.1`. |
| `version_semver` | Met | SemVer; [`CHANGELOG.md`](../CHANGELOG.md) states adherence. |
| `version_tags` | Met | Annotated tags per release; a tag push triggers `release.yml`. See [`RELEASING.md`](RELEASING.md). |
| `release_notes` | Met | [`CHANGELOG.md`](../CHANGELOG.md) (Keep a Changelog) + per-PR fragments under `changelog/`. |
| `release_notes_vulns` | Met | [`CHANGELOG.md`](../CHANGELOG.md) security entries; [`SECURITY.md`](../SECURITY.md) governs disclosure. |

## Reporting

| Criterion | Answer | Evidence |
| --- | --- | --- |
| `report_process` | Met | [`CONTRIBUTING.md`](../CONTRIBUTING.md) + `.github/ISSUE_TEMPLATE/bug.md`; security routed via [`SECURITY.md`](../SECURITY.md). |
| `report_tracker` | Met | GitHub Issues. |
| `report_responses` | Met *(attest)* | Solo maintainer acknowledges reports; structured templates + recent cadence. |
| `enhancement_responses` | Met *(attest)* | Enhancements handled via the `feature.md` template / Issues / PRs. |
| `report_archive` | Met | GitHub Issues is publicly searchable and archived. |
| `vulnerability_report_process` | Met | [`SECURITY.md`](../SECURITY.md) publishes the GitHub private-advisory flow + maintainer email. |
| `vulnerability_report_private` | Met | GitHub private security advisories are supported. |
| `vulnerability_report_response` | Met *(attest)* | [`SECURITY.md`](../SECURITY.md) commits to acknowledge within a few days; no report exceeded 14 days in the last 6 months. |

## Quality

| Criterion | Answer | Evidence |
| --- | --- | --- |
| `build` | N/A | The plugin requires no building for use — Claude Code clones the repo into its plugin cache as-is (Markdown + Bash + JSON). |
| `build_common_tools` | N/A | No build step (conditional on `build`). |
| `build_floss_tools` | N/A | No build step. Release packaging uses `git archive` (FLOSS) only. |
| `test` | Met | The 19-gate suite `tests/gates/run-all.sh` + the deterministic eval harness `tests/eval/run-eval.sh`; documented in the [gate map](../CLAUDE.md), [`CONTRIBUTING.md`](../CONTRIBUTING.md), and `tests/gates/CLAUDE.md`. |
| `test_invocation` | Met | `bash tests/gates/run-all.sh`. |
| `test_most` | Met | Gates validate every shipped component class (JSON / skills / agents / rules / hooks / docs / shell / signatures / changelog / flow fixtures); the eval lint scopes the true shipped payload. |
| `test_continuous_integration` | Met | `.github/workflows/ci.yml` runs the gate suite on every push (all branches) and PR. |
| `test_policy` | Met | [`CONTRIBUTING.md`](../CONTRIBUTING.md) + `tests/gates/CLAUDE.md`: each new component class gets a gate; the PR template requires gates green. |
| `tests_are_added` | Met | Recent PRs add gates (the Scorecard-hardening / behavioural-flow work added gates 12–19). |
| `tests_documented_added` | Met | The add-a-gate policy is documented in `tests/gates/CLAUDE.md` + [`CONTRIBUTING.md`](../CONTRIBUTING.md). |
| `warnings` | Met | ShellCheck (`-S error`), markdownlint (advisory), and JSON-parse gates. |
| `warnings_fixed` | Met | CRITICAL gates fail CI on ShellCheck / JSON / path / secret violations; a PR must be green to merge. |
| `warnings_strict` | Met | ShellCheck at error severity across all shell, plus dedicated lint gates (G8 / G9 / G10 / G14 / G17). |

## Security

| Criterion | Answer | Evidence |
| --- | --- | --- |
| `know_secure_design` | Met | [`SECURITY.md`](../SECURITY.md) documents the trust model + the two `PreToolUse` write-guards (`hooks/hooks.json`); `hooks/CLAUDE.md` explains enforcement. |
| `know_common_errors` | Met | The [gate map](../CLAUDE.md) (G1–G19) + [`SECURITY.md`](../SECURITY.md) in/out-of-scope enumerate common error classes and their mitigations. |
| `crypto_*` (all) | N/A | No cryptography on user data — see [Cryptography: not applicable](#cryptography-not-applicable). |
| `delivery_mitm` | Met | Delivered via GitHub over HTTPS (the plugin-cache clone). |
| `delivery_unsigned` | Met | The release tarball carries a `sha256` subject + SLSA v2 provenance signed via keyless OIDC (`release.yml`); transport is HTTPS. |
| `vulnerabilities_fixed_60_days` | Met | No runtime package dependencies (no `package.json`); Dependabot updates the pinned GitHub-Action SHAs weekly; no known unpatched issue of medium+ severity. |
| `vulnerabilities_critical_fixed` | Met | Same controls; rapid patch cadence. |
| `no_leaked_credentials` | Met | Gate `10-secret-scan` (CRITICAL) on every push/PR + GitHub push protection. |

## Analysis

| Criterion | Answer | Evidence |
| --- | --- | --- |
| `static_analysis` | Met | ShellCheck (gate `08-shellcheck`, `-S error`) over all shell + CodeQL (`codeql.yml`, `actions` language) over the workflows; both run in CI. |
| `static_analysis_common_vulnerabilities` | Met | ShellCheck flags quoting / injection-class shell bugs; CodeQL covers workflow-security queries; `10-secret-scan` catches leaked credentials. |
| `static_analysis_fixed` | Met | Gates run every commit/PR; CodeQL on push/PR/weekly; no open alerts. |
| `static_analysis_often` | Met | ShellCheck + path / secret / JSON gates on every push/PR; CodeQL weekly + push/PR. |
| `dynamic_analysis` | Met | The eval harness `--durability` mode re-introduces a fixed anti-pattern on a copy and confirms a shipped write-guard still blocks it (a positive control); the gate suite executes the shipped shell end-to-end. |
| `dynamic_analysis_unsafe` | N/A | Shell + Markdown — no memory-unsafe language. |
| `dynamic_analysis_enable_assertions` | Met | Gates assert on exact exit codes; the eval harness compares against a blessed `tests/eval/baseline.json` and vetoes regressions. |
| `dynamic_analysis_fixed` | Met | A failing gate, an eval regression, or a durability miss blocks the PR. |

## Maintainer attestations

Three criteria rest on a maintainer activity claim rather than a file in the repo. They are marked
*(attest)* above and confirmed by the maintainer before each BadgeApp submission:

- `report_responses` — bug reports are acknowledged.
- `enhancement_responses` — enhancement requests are acknowledged.
- `vulnerability_report_response` — no vulnerability report has gone unanswered beyond 14 days in the
  last 6 months (consistent with the few-days acknowledgement target in [`SECURITY.md`](../SECURITY.md)).

## Cryptography: not applicable

All `crypto_*` criteria are **N/A**. The plugin performs no cryptography on user data: it reads and
edits Markdown / JSON config and emits a report. The only hashing anywhere is a non-security
`sha256sum` of the release tarball, used as the SLSA provenance *subject* (an integrity digest, not
authentication of user data). Release provenance is signed with **keyless OIDC** via the SLSA
generator — the signing identity is managed by GitHub and Sigstore, not by code this project ships.
There are no keys, nonces, passwords, or key-agreement protocols to configure.

## Why some criteria read differently from a typical app

`claude-calibration` is a content-and-shell plugin, so a few criteria are answered through this
repo's own mechanisms rather than the usual app tooling:

- **No build (`build_*` = N/A).** Nothing is compiled; the repo ships as-is into the plugin cache.
- **No package dependencies.** There is no `package.json`; the only versioned dependencies are the
  GitHub Actions used in CI, all pinned by commit SHA and updated weekly by Dependabot.
- **Static analysis is ShellCheck + CodeQL.** ShellCheck covers the Bash that does the work; CodeQL
  (`actions` language) covers the workflow YAML.
- **Dynamic analysis is the eval harness, not a fuzzer.** The durability check is a behavioural
  positive control — it proves a shipped guard still blocks a known anti-pattern — and the gate
  suite executes the shipped shell on every run.

## Sources

- Project entry point — [`README.md`](../README.md)
- Disclosure & trust model — [`SECURITY.md`](../SECURITY.md)
- Contribution process & gate suite — [`CONTRIBUTING.md`](../CONTRIBUTING.md)
- Gate map (G1–G19) — [`CLAUDE.md`](../CLAUDE.md)
- Release notes — [`CHANGELOG.md`](../CHANGELOG.md)
- Release procedure — [`RELEASING.md`](RELEASING.md)
- How the plugin evaluates a setup — [`self-calibration.md`](self-calibration.md)
- Vocabulary — [`glossary.md`](glossary.md)
- OpenSSF Best Practices Badge — <https://www.bestpractices.dev/>
