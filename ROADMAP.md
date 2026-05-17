# Roadmap

This roadmap is a sketch, not a commitment. Items move based on real usage.

> **v0.1.0 is an initial release.** Try it with `--mode commands-only` or
> `--mode safe` first. See `docs/SECURITY.md` before enabling `full`.

## v0.1.0 — Initial release

- Four quality-gate slash commands for Claude Code.
- Cross-platform installers with `commands-only`, `safe`, and `full` modes.
- Doctor scripts that report `READY` / `PARTIAL` / `ACTION REQUIRED`.
- Uninstall scripts that preserve unrelated settings.
- Documentation: README, INSTALLATION, SECURITY, ARCHITECTURE, QUALITY-GATES,
  COMPARISON, EXAMPLE-RUN, CONTRIBUTING, CHANGELOG.

## v0.1.x — Hardening

Targeted follow-ups before a v0.2.0 minor bump:

- **Installer smoke tests.** Run `--mode commands-only` against a tempdir
  on macOS, Linux, WSL, and Windows in CI.
- **Safer auto-save** once the Claude Code hook payload schema is confirmed
  from official docs. Goal: stage only files just touched by Claude Code,
  not the entire working tree.
- **Better plugin detection.** Stop relying on substring matches against
  `settings.json` for `superpowers` and `compound-engineering`.
- **Project-scoped install mode.** Allow installing commands and hooks into a
  per-project `.claude/` instead of the global `~/.claude/`.
- **Doctor verdict tuning.** Make optional integrations classifiable so the
  `PARTIAL` verdict can be tightened.

## Future — Nice to have

- Real before/after example runs from public repositories.
- Integrations with additional AI coding tools where it makes sense and where
  Vibekit can stay a local quality-gate layer (not an agent).
- Optional CI checks that run a subset of the gates in pull requests.
- Better learning persistence (deduplication, decay, project vs global priors).
- Translations beyond Korean.

## What is out of scope

- Autonomous code generation. Vibekit is a review and safety layer.
- Hosted dashboards, SSO, compliance certifications.
- Automatic push, merge, or deploy. These remain human decisions.
