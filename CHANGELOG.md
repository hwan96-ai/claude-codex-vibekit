# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — Initial public release candidate

First public release. Treat as early — try with `--mode commands-only` or
`--mode safe` first, and review `docs/SECURITY.md` before enabling `full`.

### Added
- Four quality-gate slash commands for Claude Code:
  - `/hwan-refactor-idea` (PRD gate)
  - `/hwan-refactor-code` (code gate)
  - `/hwan-refactor-design` (design gate)
  - `/hwan-refactor-git` (release gate)
- `/git-safe` slash command for project-level git safety setup.
- Cross-platform installers with three modes:
  - `commands-only` — slash commands only, no hooks, no `settings.json` changes.
  - `safe` — adds PreToolUse (block dangerous git) and SessionStart (branch
    safety) hooks. Auto-commit is **not** enabled.
  - `full` — additionally enables auto-save / auto-commit (PostToolUse).
- `install.sh` and `install.ps1` with idempotent JSON merging via Python,
  automatic backup of `~/.claude/settings.json`, and explicit warning before
  enabling `full` mode.
- `doctor.sh` and `doctor.ps1` that report required and optional dependencies,
  Vibekit files, and configured hook entries. Exit with `READY`, `PARTIAL`, or
  `ACTION REQUIRED`.
- `uninstall.sh` and `uninstall.ps1` that remove Vibekit's commands, hooks, and
  the hook entries it added to `settings.json`, while preserving unrelated
  settings and `learnings/`.
- Documentation:
  - `README.md` — positioning, audience, comparison to Cursor / Aider / Cline
    / Continue, install modes, safety model.
  - `docs/INSTALLATION.md` — install modes, path detection, doctor verdicts,
    recovery, troubleshooting.
  - `docs/SECURITY.md` — what the installer modifies, mode risk profiles,
    `git add -A` behavior in `full` mode, global hook scope, backup, recovery.
  - `docs/ARCHITECTURE.md` — system layers and gate pipeline (unverified gstack
    command names removed).
  - `docs/QUALITY-GATES.md` — existing workflow doc, retained.
  - `docs/COMPARISON.md` — neutral tool comparison.
  - `docs/EXAMPLE-RUN.md` — illustrative audit-only run.
  - `CONTRIBUTING.md`, `ROADMAP.md`, this `CHANGELOG.md`.

### Known caveats
- `auto-save.sh` (only registered in `full` mode) runs `git add -A`. It stages
  the entire working tree, including changes unrelated to Claude Code's edits.
  This is documented in `README.md`, `docs/INSTALLATION.md`, and
  `docs/SECURITY.md`. Most users should stay on `--mode safe`.
- Hooks installed under `~/.claude` are global. They affect every Claude Code
  session on the user account, not only the project where Vibekit was cloned.
  Choose `--mode commands-only` to avoid this.
- Plugin presence detection for `superpowers` and `compound-engineering` is a
  heuristic substring match against `settings.json`.

### Removed
- `.claude/templates/settings.template.json` (legacy; installers now compose
  hook entries directly in Python for robustness).
