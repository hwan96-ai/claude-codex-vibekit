# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_No unreleased changes after v0.2.5 yet._

## [0.2.5] — prepared (release candidate, tag not yet cut)

Hook-safety and documentation polish over v0.2.4. Two merged PRs combined:
PR #11 (docs / CI / executable bits) and PR #12 (hook safety gaps).
Behavior-only changes to hooks; no installer or doctor flow changes.

### Changed
- `.claude/hooks/auto-save.sh`: the deletion guard now runs in both payload
  and fallback staging modes. Previously payload mode skipped the check
  because the payload helper silently dropped missing paths; the README
  guard ("refuses on deletions unless `HWAN_AUTOSAVE_ALLOW_DELETIONS=1`")
  now matches actual behavior in every mode (PR #12).
- `.claude/hooks/block-dangerous-git.py`: blocks two more destructive
  push options:
  - `git push --mirror` (rewrites every remote ref from local refs and
    can delete protected branches without naming them).
  - `git push --prune` (deletes remote refs not present locally).
- `.claude/hooks/block-dangerous-git.py`: hardens the `git -c` argv
  parser so a malformed config token cannot hide a destructive
  subcommand. Three shapes now handled:
  - `git -c key=value …` (well-formed) — both tokens consumed as before.
  - `git -c <destructive-verb> …` (e.g. `git -c reset --hard`) — only
    `-c` is consumed; the verb is detected normally.
  - `git -c <junk> <destructive-verb> …` (e.g. `git -c foo reset --hard`)
    — both `-c` and the junk are consumed; the verb that follows is
    detected normally.

### Documentation
- `README.md` / `README.ko.md` / `docs/INSTALLATION.md`: clarify that
  `--scope project` only redirects Claude command/hook installs.
  Codex custom prompts always install under `$CODEX_HOME/prompts`
  (default `~/.codex/prompts`) because the Codex CLI does not read
  project-local prompt paths (PR #11).
- `README.md` / `README.ko.md` / `CONTRIBUTING.md`: stale `v0.1.x` /
  `v0.2.3` references replaced with `v0.2.x` / `v0.2.4`; "Project-scoped
  install mode" removed from the contribution wishlist (already
  shipped). Restored the curated v0.2.4-era README and CHANGELOG that
  an earlier installer-hardening merge had inadvertently truncated
  (PR #11).

### Added
- `install.sh` / `install.ps1`: the `bash`-required error message in
  `safe`/`full` modes now points users at `--mode commands-only` as
  a no-bash escape hatch (PR #11). `commands-only` itself was already
  bash-free; this is wording only.
- `.github/workflows/smoke-tests.yml`: a new "End-to-end smoke" step
  in both the Ubuntu and Windows jobs runs `tests/smoke.sh` /
  `tests/smoke.ps1`. These exercise `safe` + `full` install hook
  runtime embedding, protected-branch commit refusal, and the
  placeholder-vs-real secret pattern guard — none of which were
  previously running in CI (PR #11).
- `tests/test-auto-save.sh`: 3 new cases — payload-mode deletion
  refusal, `HWAN_AUTOSAVE_ALLOW_DELETIONS=1` escape hatch in payload
  mode, and a fallback-mode deletion regression guard (PR #12).
- `tests/test-block-dangerous-git.py`: 10 new cases covering
  `--mirror` / `--prune` and the three malformed `git -c` shapes,
  plus positive `git -c key=value` allows (PR #12).

### Fixed
- `install.sh`, `doctor.sh`, `uninstall.sh`, `tests/smoke.sh`,
  `tests/smoke-install.sh`, `tests/test-auto-save.sh` now have the
  POSIX executable bit set (mode `100755`). On Linux, `tests/smoke.sh`
  invokes `install.sh` directly via its shebang; the missing exec bit
  caused the new "End-to-end smoke" CI step to fail with
  `Permission denied (126)` until this was fixed (PR #11).

### Notes
- No tag has been cut for these changes yet. The latest tagged release
  is still `v0.2.4`. The "Release candidate verification (v0.2.5)"
  section in `README.md` refers to the prepared commit, not to an
  existing tag.
- Prior post-v0.2.4 commits already on `main` and included in this
  release: `2027767` (Codex prompt install path), `42a05a5` (installer
  hook runtime hardening), `9aae9c9` and `74b2826` (auto-save / git
  safety payload handling). PRs #11 and #12 land on top of those.

## [0.2.4] — 2026-05-18

README visual polish. Documentation-only. No installer, hook, script,
slash-command, CI, or `SHA256SUMS` behavior changes.

### Changed
- `README.md` first screen restructured for a cleaner landing-page feel:
  - New **"The 30-second version"** bullet list right under TL;DR (you
    direct the work, Claude Code generates code, Vibekit adds local
    gates, start with `--audit-only`, no automatic push/PR/merge/deploy).
  - The top **Mermaid workflow diagram is now wrapped in `<details>`**
    so it does not dominate the fold. The text fallback
    (`PRD → Code → Design → Release`) stays visible at all times.
  - New **Before / After** comparison table (output, files touched,
    commits/push, repeatability) immediately after the workflow line.
  - "Current release verification" header bumped from v0.2.1 → v0.2.3,
    and the `git checkout v0.2.1` examples in the Verify-release-files
    section updated to `git checkout v0.2.3` so the snippets match the
    actual current tag.
  - New **"Recommended next docs"** mini-index above the full
    Documentation list (Installation → Example run → Security →
    Comparison) so first-time readers have a guided path.
- `README.ko.md` mirrors the same shape in natural Korean (30초 요약,
  Before/After 표, `<details>` 다이어그램, v0.2.3 검증 헤더,
  다음에 볼 문서).

### Added
- `docs/assets/doctor-ready.svg` — a small text-based SVG terminal card
  showing an illustrative `doctor.sh` run (`READY`, commands ok, hooks
  verified, optional integrations partial). Referenced inline in the
  English and Korean "Current release verification" sections. No binary
  screenshots, no external image hosting.

### Verified during this polish
- Repo-wide grep for `YOUR-USERNAME`, `[YOUR NAME]`, `d octor`, and
  `.\d octor` against the polished tree: no active occurrences in
  README content; only historical audit-finding references in
  `CHANGELOG.md` / `ROADMAP.md` remain (same as v0.2.3 baseline).
- All inline tag references in `README.md` and `README.ko.md` now read
  `v0.2.3` rather than `v0.2.1`. The `Latest release` shields.io badge
  continues to resolve dynamically.
- Overclaim phrase scan in both READMEs: no "production-ready",
  "battle-tested", "verified at every step", "mistakes don't repeat",
  "safety without slowing down", or "one command install" (English or
  Korean equivalents).
- `docs/assets/doctor-ready.svg` is a text SVG (`<?xml ... ?>` +
  `<svg>` root, well-formed, no embedded raster).

### Not changed
- `install.sh`, `install.ps1`, `doctor.sh`, `doctor.ps1`, uninstall
  scripts, hooks, slash commands, tests, CI workflow, `SHA256SUMS`,
  release tags, and the published GitHub releases for v0.2.1 / v0.2.2
  / v0.2.3.

## [0.2.3] — 2026-05-18

README hotfix. Documentation-only. No installer, hook, script, or
slash-command behavior changes.

### Changed
- `README.md` Install section trimmed: removed the duplicated
  "Recommended" clone/install block (the same commands already appear
  in the top TL;DR), collapsed the Project-scoped install block into a
  short callout under the mode table, and shortened the Opt-in
  bootstrap block to one paragraph. Full walkthrough now lives in
  [`docs/INSTALLATION.md`](docs/INSTALLATION.md), linked from the new
  closing line of the Install section.
- `README.md` install-modes table now has a third column ("Who it's
  for") so picking a mode does not require reading paragraph text.
- `README.ko.md` mirrors the same simplification in natural Korean.

### Verified during this hotfix
- Repo-wide grep for `YOUR-USERNAME`, `[YOUR NAME]`, `d octor`,
  `.\d octor` against the v0.2.2 tree found no active occurrences in
  README content; the only matches are historical audit-finding
  references in `CHANGELOG.md` and `ROADMAP.md`. No literal placeholder
  or `doctor` typo was present to fix — the simplification removes the
  duplicated install block that would have been the place such a typo
  could have hidden.
- All README copy-paste commands (`./install.sh ...`,
  `.\install.ps1 ...`, `./doctor.sh ...`, `.\doctor.ps1 ...`,
  `bash scripts/generate-checksums.sh --check`,
  `.\scripts\generate-checksums.ps1 -Check`) match the scripts on disk.

### Not changed
- `install.sh`, `install.ps1`, `doctor.sh`, `doctor.ps1`, uninstall
  scripts, hooks, slash commands, tests, CI workflow, `SHA256SUMS`,
  release tags, or GitHub releases.

## [0.2.2] — 2026-05-18

Documentation-only polish for the README landing page. No installer, hook,
script, or slash-command behavior changes.

### Changed
- `README.md` first screen: added a short "Why this exists" paragraph, a
  compact "What you get" list, a clearly-labeled illustrative
  `--audit-only` example output, and a short text fallback under the
  Mermaid workflow diagram for readers whose viewer does not render
  Mermaid.
- `README.md`: new "Current release verification (v0.2.1)" section that
  enumerates the specific checks that pass for the v0.2.1 tag — fresh
  clone + safe install, doctor hook runtime verification,
  `SHA256SUMS --check` on both platforms, CI smoke tests. Phrased as
  release-specific, not as a general stability claim.
- `README.md`: documentation index now links to
  `docs/GITHUB-PUBLISHING.md`.
- `README.ko.md`: same structural additions in natural Korean, mirroring
  positioning and the illustrative-example warning.

### Notes
- No changes to `install.sh`, `install.ps1`, `doctor.sh`, `doctor.ps1`,
  uninstall scripts, hooks, slash commands, `SHA256SUMS`, CI workflow,
  release tags, or GitHub releases.

## [0.2.1] — 2026-05-18

Release-gate hardening. Addresses three findings from the v0.2.0 release
audit: no install integrity artifact, installer reported success without
verifying that copied hooks actually run, and doctor could not distinguish
"configured" from "verified". No changes to slash command behavior or
what `block-dangerous-git.py` blocks.

### Added
- `SHA256SUMS` covering the 15 release-relevant files (install / doctor /
  uninstall scripts on both platforms, all four hooks, all five slash
  commands).
- `scripts/generate-checksums.sh` and `scripts/generate-checksums.ps1` to
  regenerate or verify `SHA256SUMS`. Bash and PowerShell produce
  byte-identical output (`<sha256>  <relative/path>`, two spaces, lowercase
  hash, forward-slash paths).
- Installer step `[4.5] Verifying installed hooks (post-copy runtime smoke)`
  in both `install.sh` and `install.ps1`. After copying hooks and merging
  settings, the installer now verifies: (a) required hook files are
  present, (b) Python hooks compile via `py_compile`, (c) shell hooks pass
  `bash -n` when bash is available (warning, not failure, on Windows
  without bash), (d) `block-dangerous-git.py` actually allows a harmless
  push and blocks a force push, (e) every hook command path in
  `settings.json` / `settings.local.json` resolves to a real file. If any
  check fails, the installer exits non-zero and prints OS-specific
  diagnostic next steps (Gatekeeper / Defender / SELinux).
- Doctor section `[hook runtime verification]` in both `doctor.sh` and
  `doctor.ps1`. Same five checks as the installer, plus an explicit note
  that "configured" (a settings.json entry) is not the same as "verified"
  (the referenced file exists, compiles, and primary smoke passes).
  Runtime failures count toward `ACTION REQUIRED`.

### Documentation
- New "Verify release files" section in `README.md` and `README.ko.md`
  explaining `SHA256SUMS` honestly: what it does protect against
  (download tampering, accidental corruption) and what it does not
  (compromised repository owner account).
- `docs/INSTALLATION.md`: how to install from a tag, how to verify
  `SHA256SUMS`, what the installer verifies after copying hooks, what to
  do if hook verification fails.
- `docs/SECURITY.md`: supply-chain limitations of `SHA256SUMS`, how the
  installer's post-copy hook verification works, why OS security tools
  cannot be fully controlled by the installer.
- `docs/GITHUB-PUBLISHING.md`: release checklist now requires
  regenerating `SHA256SUMS` and running doctor's hook runtime
  verification before tagging.
- `ROADMAP.md`: v0.2.1 listed as in-progress; v1.0.0 unchanged.

### Notes on the v0.2.0 audit
- The "YOUR-USERNAME / [YOUR NAME] placeholder" P0 was reclassified as
  STALE: those placeholders were removed in v0.2.0 (commit
  `bbe5322 docs: replace remaining GitHub username placeholders`). A
  repo-wide grep on the v0.2.1 branch returns zero matches.
- The "Gatekeeper / Defender silence" finding was reframed as **hook
  runtime smoke verification**. We cannot fully control OS security tools
  from a userspace installer; we can verify the files exist, compile, and
  the primary safety hook actually blocks what it should. The installer
  and doctor now both do that and report honestly if they cannot.

## [0.2.0] — 2026-05-18

Onboarding and trust polish release. No changes to install behavior, hook
logic, or what the dangerous-git hook blocks. Documentation, README first
impression, and visual onboarding only.

### Added
- README TL;DR block with copy-paste install + first audit-only command.
- Mermaid diagrams in README for the quality-gate flow and install-mode
  progression. Source files under [`docs/assets/`](docs/assets/) for reuse
  outside GitHub.
- CI smoke-tests status badge and a latest-release badge in both READMEs.
- Extended [`docs/EXAMPLE-RUN.md`](docs/EXAMPLE-RUN.md): illustrative
  audit-only outputs for all four gates (PRD, Code, Design, Release), a
  plain-English "How to interpret PARTIAL from doctor" section, and a
  "first 10 minutes" walkthrough.
- New onboarding sections in [`docs/INSTALLATION.md`](docs/INSTALLATION.md):
  "Which mode should I choose?", "Recommended path for first-time users",
  "Global vs project-scoped install", "What PARTIAL means", "What to do if
  doctor says ACTION REQUIRED", "How to update an existing install",
  "When to use --bootstrap", "When NOT to use full mode".
- Quick trust summary at the top of [`docs/SECURITY.md`](docs/SECURITY.md).
- New [`docs/GITHUB-PUBLISHING.md`](docs/GITHUB-PUBLISHING.md): release
  checklist, recommended topics, badge update notes, post-release smoke
  test reminder.
- Updated [`README.ko.md`](README.ko.md) to mirror the polish (TL;DR,
  badges, Mermaid, PARTIAL note).

### Changed
- README opening line now leads with positioning ("Not another AI coding
  agent") instead of the v0.1.0 release tag.
- `ROADMAP.md` shows v0.2.0 in progress and adds a conservative v1.0.0
  checklist (external user feedback, stable install across OSes, docs
  verified by a new user, no critical install regressions, written
  support/security policy).

### Not changed
- `install.{sh,ps1}`, `doctor.{sh,ps1}`, `uninstall.{sh,ps1}`, hook
  scripts, tests, CI workflow. Behavior is identical to v0.1.3.

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
