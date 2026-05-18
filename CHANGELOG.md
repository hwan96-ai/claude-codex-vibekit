# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] — 2026-05-18

Quality and safety improvements for the installer and hooks. No changes to
the slash-command behavior. No changes to which operations the dangerous-git
hook blocks.

### Added
- **CI smoke tests** (`.github/workflows/smoke-tests.yml`) running on Ubuntu
  and Windows for every PR and push to `main`. Each job parses the install
  and doctor scripts, runs `tests/test-block-dangerous-git.py`, performs an
  installer smoke test against an isolated `CLAUDE_HOME`, and asserts the
  five slash commands were copied. Doctor exit `READY` or `PARTIAL` is
  treated as success; `ACTION REQUIRED` fails the build. The CI does not
  require Claude Code, gstack, BMAD, superpowers, compound-engineering, or
  Codex to be present.
- **Project-scoped install** via `--scope project` (Bash) / `-Scope project`
  (PowerShell). Installs commands, hooks, and settings into `./.claude` of
  the current project instead of the global `~/.claude`. Settings go to
  `settings.local.json` to match Claude Code's machine-local convention.
  Running project-scope install inside the Vibekit repo itself now prints a
  warning and requires confirmation (or `--yes` / `-Yes`).
- **Explicit Claude home path** via `--claude-home <path>` /
  `-ClaudeHome <path>` for both installer and doctor — useful for CI and for
  exotic layouts.
- **Payload-aware auto-save** (full mode). New env var
  `HWAN_AUTOSAVE_STAGE_MODE=auto|payload|all` (default `auto`). In `auto` or
  `payload` mode, the hook parses the Claude Code stdin JSON and, if it can
  extract a validated, in-repo file list, stages only those paths instead of
  `git add -A`. `auto` falls back to the existing guarded `git add -A` when
  the payload is absent or unusable; `payload` refuses to commit in that
  case; `all` skips parsing and uses `git add -A` directly. All existing
  safeguards (branch, risky paths, secrets, max files, deletions) still
  apply.
- `tests/test-auto-save.sh` — covers payload-only staging, payload refusal,
  fallback, kill switch, outside-repo path rejection, and risky-path
  refusal.
- `tests/smoke-install.sh` and `tests/smoke-install.ps1` — driver scripts
  used by CI and runnable locally.

### Changed
- **Doctor verdicts are clearer.** Output is split into
  `[core readiness]`, `[hook configuration]`, `[optional integrations]`, and
  `[recommended next steps]`. Each missing item gets a single-line fix
  command. Doctor now returns `PARTIAL` when safe-mode hooks (`PreToolUse`
  and `SessionStart`) are not configured — typical for `commands-only`
  installs — instead of conflating that with optional-tool gaps.
  Unparseable `settings.json` is now `ACTION REQUIRED`.
- **Plugin detection** now checks both `settings.json` and
  `settings.local.json`, the project-local `./.claude/`, the global
  `~/.claude/plugins` and `~/.claude/skills`, and `~/.codex/plugins` /
  `~/.codex/skills`. Wording was tightened from "not installed" to
  "not detected by doctor (heuristic)" — the check is still a heuristic.
- Bash `--yes` / `-y` is now a general non-interactive flag (also covers
  the project-scope confirmation). Use `--bootstrap-yes` to also opt into
  bootstrap. Previously `--yes` implied `--bootstrap`. The PowerShell `-Yes`
  no longer auto-enables `-Bootstrap`.

### Documented
- README, README.ko, `docs/INSTALLATION.md`, `docs/SECURITY.md`, and
  `ROADMAP.md` cover project-scope install, the new doctor verdict layout,
  the `HWAN_AUTOSAVE_STAGE_MODE` modes, and the plugin-detection heuristic
  caveat. The existing `git add -A` warning is retained.

## [0.1.2] — 2026-05-18

Refines the PreToolUse `block-dangerous-git.py` hook so it stops destructive
and history-rewriting git operations without blocking normal pushes.

### Changed
- `block-dangerous-git.py` is now token-based (`shlex`) instead of substring
  matching. The previous version blocked any command containing the literal
  token `main` — including `git push origin main` and `git push -u origin main`
  — which got in the way of intentional releases from `main`.
- Direct-commit protection on `main`/`master` now keys off the *current
  branch* (`git rev-parse --abbrev-ref HEAD`), not the command line text.
- Force-push detection now matches `--force`, `-f`, and `--force-with-lease`
  as flags, including `--force-with-lease=origin/main`.
- Added explicit blocks for `git push origin --delete <protected>`,
  `git push origin :<protected>`, `git branch -D`, `git commit --amend`,
  and `git rebase` while on `main`/`master`.
- Force-update refspecs are now blocked: any `git push` refspec starting
  with `+` (e.g. `+main`, `+HEAD:main`, `+feature:main`,
  `+refs/heads/feature:refs/heads/main`) is treated as a force push.
- Conservative regex fallback retained for cases where shlex tokenization
  fails on unusual shell syntax.

### Allowed (previously blocked)
- `git push origin main`, `git push -u origin main`, `git push`,
  `git push origin HEAD:main`, `git push origin v0.1.2`,
  `git push origin --tags`, `git commit -m "fix main bug"` on a feature
  branch. Force pushes and destructive operations remain blocked.

### Added
- `tests/test-block-dangerous-git.py` — self-contained checks (no test
  framework dependency) for the allow/block matrix above. Run with
  `python tests/test-block-dangerous-git.py`.
- `VIBEKIT_HOOK_TEST_BRANCH` env var lets tests inject the current branch
  without spawning git.

### Documented
- `docs/SECURITY.md` clarifies that the hook blocks destructive and
  history-rewriting operations only; normal non-force pushes (including to
  `main`) are not blocked. PR / merge / deploy remain manual as before.

## [0.1.1] — 2026-05-18

Quality-of-life and safety improvements. No breaking changes to install modes.

### Added
- Opt-in `--bootstrap` flag for `install.sh` and `-Bootstrap` for `install.ps1`.
  When passed, the installer can clone gstack into `~/.claude/skills/gstack`
  and run its `./setup`. Adding `--bootstrap-codex` / `-BootstrapCodex` also
  attempts `npm install -g @openai/codex`. BMAD, superpowers, and
  compound-engineering are still surfaced as manual steps with exact commands
  (BMAD is project-local; plugins must go through Claude Code's plugin UI).
- `--fix` flag for `doctor.sh` and `-Fix` for `doctor.ps1`. Performs the same
  safe-auto-install pass as bootstrap for tools with clear CLI flows.
- Both bootstrap and `--fix` modes print an end-of-run report split into:
  installed automatically, skipped, manual steps required, and failures with
  recovery commands.
- Auto-save kill switch and tuning knobs via environment variables:
  `HWAN_AUTOSAVE_DISABLE=1`, `HWAN_AUTOSAVE_MAX_FILES=N` (default 30),
  `HWAN_AUTOSAVE_ALLOW_DELETIONS=1`.

### Changed
- `auto-save.sh` (only registered in `full` mode) now refuses to commit when
  any of the following are true, before falling back to `git add -A`:
  not in a git repo; on `main`/`master`; risky filenames in the change set
  (`.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa`,
  `id_ed25519`, `.claude/settings.json`, `.claude/settings.local.json`);
  obvious secret patterns in the diff (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
  `BEGIN PRIVATE KEY`, `sk-*`); change set larger than
  `HWAN_AUTOSAVE_MAX_FILES`; deletions present unless explicitly allowed. On
  pass, it prints a short summary (branch, file count, paths) and commits as
  `autosave: claude changes <timestamp>`.
- Default install path is unchanged. Bootstrap is strictly opt-in.

### Documented
- README, README.ko, `docs/INSTALLATION.md`, and `docs/SECURITY.md` describe
  the new flags and the auto-save safeguards. The existing warning that `full`
  mode still uses `git add -A` after the checks is retained.

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
