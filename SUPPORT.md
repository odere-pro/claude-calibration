# Support

Need help with `claude-calibration`? Here's where to look.

## Self-service first

- **First-time setup** — run `/claude-calibration:calibration-onboarding` in a session; it detects
  what config you have and recommends one minimal next step.
- **Installing / verifying / updating** — [`docs/install.md`](docs/install.md), including a
  troubleshooting table for the common "skill not showing / context cost looks wrong" cases.
- **Using the flows** — [`docs/usage.md`](docs/usage.md) (intents, the recurrence →
  enforcement-creation flow, per-feature shortcuts, reading the run-folder files).
- **Vocabulary** — [`docs/glossary.md`](docs/glossary.md).
- **Is something just structurally broken?** — run `/claude-calibration:calibration-doctor` for a
  ~5-second health check (JSON parses, hook scripts present + executable, frontmatter valid).

## Questions and bugs

- **Bugs** — open a GitHub issue using the **Bug report** template. Include the command you ran,
  your Claude Code version, and the relevant `/plugin` / `/skills` output.
- **Ideas / feature requests** — open an issue using the **Feature request** template.
- **Security issues** — do **not** open a public issue; see [`SECURITY.md`](SECURITY.md).

## Contributing

If you want to fix or extend something yourself, start with [`CONTRIBUTING.md`](CONTRIBUTING.md).
