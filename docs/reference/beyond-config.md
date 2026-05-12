[← README](../README.md) · [Glossary](../glossary.md)

# Beyond config — tools that evaluate code & running apps

These tools evaluate **code** or a **running application**, not your Claude Code `.claude/` config.
They're collected here so the inventory is complete; for config evaluators, see each feature doc's
**Validate** section and [`general-setup.md`](../general-setup.md) **Validate**.

Labels: **[built-in]** (the CLI), **[bundled skill]** (ships with Claude Code), and
agents/skills without a label are **plugin- or setup-provided** (install/check via `/plugin`).
Claude Code's *own* code-review surface is small: `/review`, `/security-review` (built-in commands,
also reachable via the Skill tool), `/simplify` and `/debug` (bundled skills), and the built-in
subagents `Explore` / `Plan` / `general-purpose`. Everything else below comes from plugins (e.g.
the official `pr-review-toolkit`) or this user's setup.

## Code

| Invoke | What it does |
|--------|--------------|
| `/review [PR]` · `/security-review` **[built-in]** | Reviews a PR (or pending branch changes) for issues; `/security-review` focuses on vulnerabilities. |
| `/simplify [focus]` **[bundled skill]** | Reviews recently changed files for reuse, quality, and efficiency, and applies fixes. |
| `/debug [description]` **[bundled skill]** | Enables debug logging and walks through diagnosing a failure. |
| `code-reviewer` agent + `<lang>-reviewer` agents (`typescript-`, `python-`, `go-`, `rust-`, `java-`, `kotlin-`, `csharp-`, `cpp-`, `flutter-`, `database-`, `healthcare-`) | Reviews a diff for bugs, style, and that language's idioms. |
| `security-reviewer` agent | Scans code for OWASP-class vulnerabilities and leaked secrets. |
| `type-design-analyzer` agent | Rates a type's encapsulation, invariants, usefulness, and enforcement. |
| `silent-failure-hunter` agent | Finds swallowed errors, empty catches, and bad fallback behavior. |
| `comment-analyzer` agent | Checks comments for accuracy and comment-rot risk. |
| `pr-test-analyzer` agent · `/test-coverage` | Assesses whether tests meaningfully cover new behavior and edge cases. |
| `code-simplifier` agent | Flags redundancy and over-complexity in recently changed code. |
| `/quality-gate` | Runs an aggregate quality gate over the change. |
| `performance-optimizer` agent | Identifies performance bottlenecks and proposes fixes. |
| `a11y-architect` agent | Audits UI against WCAG accessibility requirements. |
| `seo-specialist` agent | Audits pages for technical SEO issues. |

## Running app / model output

| Invoke | What it does |
|--------|--------------|
| `gan-evaluator` agent | Drives the live app via Playwright, scores it against a rubric, and feeds feedback back to the generator. |
| `eval-harness` skill | Builds and runs an evaluation harness for an LLM feature. |
| `verification-loop` skill | Runs a structured verify-then-retry loop until output meets criteria. |
| `e2e-runner` agent | Generates and runs end-to-end tests for critical user flows. |

## Sources

- Commands reference (built-in `/review`, `/security-review`; bundled `/simplify`, `/debug`; built-ins via the Skill tool) — <https://code.claude.com/docs/en/commands>
- Subagents (built-in `Explore` / `Plan` / `general-purpose`) — <https://code.claude.com/docs/en/sub-agents>
- (Everything else is plugin- or setup-provided — install/inspect via `/plugin`.)
