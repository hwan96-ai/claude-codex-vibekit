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

## v0.1.1 — Shipped in this branch

- **Opt-in bootstrap** (`install.sh --bootstrap`, `install.ps1 -Bootstrap`)
  for gstack and (with `--bootstrap-codex` / `-BootstrapCodex`) the Codex CLI.
  BMAD, superpowers, and compound-engineering remain manual with exact
  commands surfaced in the report.
- **`doctor --fix` / `doctor -Fix`** runs the same safe-auto-install pass.
- **Safer auto-save**: refuses to commit on protected branches, with risky
  files in the change set, with secret patterns in the diff, with deletions
  (unless opted in), or when the change set exceeds a conservative threshold.
  Still uses `git add -A` after checks pass — documented as such.

## v0.1.2 — In progress

- **Refined dangerous-git hook push detection.** `block-dangerous-git.py` now
  uses token-based parsing (`shlex`) and current-branch detection instead of
  string-matching `main` in the command. Normal non-force pushes to `main`
  (`git push origin main`, `git push -u origin main`, tag pushes) are no
  longer blocked. Force pushes, `git reset --hard`, dangerous `git clean`,
  protected-branch deletion, `git commit --amend`, and direct commits on
  `main`/`master` remain blocked. Covered by
  `tests/test-block-dangerous-git.py`.

## v0.1.3 — Shipped in this branch

- **CI smoke tests** on Ubuntu and Windows: shell/PowerShell parse,
  block-dangerous-git unit tests, and isolated-`CLAUDE_HOME` install +
  doctor run.
- **Project-scoped install** (`--scope project` / `-Scope project`) with a
  guard that warns when run inside the Vibekit repo itself.
- **Payload-aware auto-save** via `HWAN_AUTOSAVE_STAGE_MODE=auto|payload|all`.
  When the Claude Code hook payload provides validated, in-repo file paths,
  the hook stages only those. Falls back to the guarded `git add -A` when
  payload is absent (auto) or refuses (payload mode).
- **Improved doctor verdicts**: split into core / hook / optional /
  next-steps sections, with one-line fix commands per missing item.
  Unparseable `settings.json` is now `ACTION REQUIRED`.
- **Plugin detection** now checks both global and project `.claude`,
  `settings.json` and `settings.local.json`, plus `~/.codex` directories.
  Wording reflects that it is still a heuristic.

## v0.1.x — Hardening (still open)

Targeted follow-ups before a v0.2.0 minor bump:

- **Cross-platform CI for safe/full install modes**, not only
  commands-only. Currently safe/full are exercised by local validation.
- **Verified hook payload schema** when Claude Code documents one. Today
  the payload parser is conservative across versions.
- **First-class project-mode init** (e.g. `vibekit init` style helper that
  picks scope, mode, and settings.local-vs-settings.json).

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
