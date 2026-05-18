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

## v0.2.0 — In progress (onboarding & trust polish)

Documentation-only release. No install behavior changes.

- README first-screen polish: TL;DR block, CI badge, latest-release badge,
  Mermaid workflow + install-mode diagrams.
- Visual onboarding assets under `docs/assets/` (Mermaid sources).
- Extended `docs/EXAMPLE-RUN.md` with audit-only illustrations for all
  four gates, a "How to interpret PARTIAL from doctor" section, and a
  "first 10 minutes" walkthrough.
- New onboarding sections in `docs/INSTALLATION.md` (Which mode to choose,
  what PARTIAL means, what to do if ACTION REQUIRED, how to update, when
  not to use full mode).
- Quick trust summary added to `docs/SECURITY.md`.
- New `docs/GITHUB-PUBLISHING.md` with release/topic/badge checklist.
- README.ko aligned with the polish.

## v0.2.1 — In progress (release-gate hardening)

Addresses three findings from the v0.2.0 release audit.

- **`SHA256SUMS`** at the repo root covering the 15 release-relevant files,
  plus cross-platform `scripts/generate-checksums.{sh,ps1}` that produce
  byte-identical output. Documented honestly: it protects against download
  tampering, not against a compromised owner account.
- **Installer post-copy hook verification** (`[4.5]` section in both
  `install.sh` and `install.ps1`). After copying hooks and merging
  settings, the installer verifies file existence, `py_compile`, `bash -n`,
  runtime smoke against `block-dangerous-git.py`, and resolves every hook
  command path in settings. Refuses success on failure with OS-specific
  diagnostics.
- **Doctor `[hook runtime verification]`** section in both `doctor.sh` and
  `doctor.ps1`. Same checks, explicit "configured ≠ verified" wording.
  Failures count toward `ACTION REQUIRED`.
- Reframed the "Gatekeeper / Defender silence" audit finding as runtime
  hook verification (what we can actually check from userspace), with a
  documented caveat that the installer cannot fully control OS security
  tools.
- The "YOUR-USERNAME / [YOUR NAME] placeholder" audit P0 was reclassified
  as STALE (already fixed in v0.2.0); confirmed by repo-wide grep on the
  v0.2.1 branch.

## v0.2.4 — In progress (README visual polish)

Documentation-only. No installer, hook, script, slash-command, CI, or
`SHA256SUMS` changes. Focus is reducing the "long accumulated doc" feel
of the landing page.

- New "The 30-second version" bullet list directly under TL;DR so a
  first-time reader sees the value contract (you direct, Claude Code
  generates, Vibekit gates, audit-only first, no automatic
  push/PR/merge/deploy) without scrolling.
- Top Mermaid workflow diagram moved into a `<details>` block; the
  `PRD → Code → Design → Release` text line stays visible at all times.
- New "Before / After" comparison table (output, files touched,
  commits/push, repeatability) so the value is concrete instead of
  abstract.
- "Current release verification" header and example `git checkout`
  commands bumped from v0.2.1 → v0.2.3 to match the actual current tag.
- New "Recommended next docs" mini-index above the full Documentation
  list (Installation → Example run → Security → Comparison).
- New text SVG terminal card at `docs/assets/doctor-ready.svg` shown
  inline in the release-verification section. No binary screenshots,
  no external image hosting.
- README.ko aligned to the same shape with natural Korean.
- v1.0.0 stability criteria unchanged.

## v0.2.3 — In progress (README hotfix)

Documentation-only. No installer, hook, script, or slash-command
behavior changes. Reacts to a live GitHub README review of the v0.2.2
landing page.

- README Install section trimmed: dropped the duplicated "Recommended"
  clone/install block (already covered by the top TL;DR), collapsed
  the Project-scoped install and Opt-in bootstrap blocks into compact
  paragraphs, and pointed at `docs/INSTALLATION.md` for the full
  walkthrough.
- Install-modes table gained a "Who it's for" column so picking a mode
  does not require reading paragraph text.
- README.ko aligned to the same shape with natural Korean.
- Repo-wide check for stale `YOUR-USERNAME`, `[YOUR NAME]`, and
  `d octor` patterns: only historical audit-finding references remain
  in CHANGELOG / ROADMAP. No active placeholders or `doctor` typo in
  README content.
- v1.0.0 stability criteria unchanged.

## v0.2.2 — In progress (README landing polish)

Documentation-only. No installer, hook, script, or slash-command behavior
changes. Focus is on first-impression clarity for the GitHub landing page.

- README first-screen polish: short "Why this exists" paragraph, compact
  "What you get" list, a clearly-labeled illustrative `--audit-only`
  example output, and a small text fallback under the Mermaid workflow
  diagram.
- New "Current release verification (v0.2.1)" section in README, phrased
  as release-specific (fresh clone safe install, doctor hook runtime
  verification, `SHA256SUMS --check`, CI smoke tests) — not as a general
  stability claim.
- README documentation index links to `docs/GITHUB-PUBLISHING.md`.
- README.ko aligned to the same structure with natural Korean rather than
  literal translation.

## v0.1.x — Hardening (still open)

Targeted follow-ups, no specific version commitment:

- **Cross-platform CI for safe/full install modes**, not only
  commands-only. Currently safe/full are exercised by local validation.
- **Verified hook payload schema** when Claude Code documents one. Today
  the payload parser is conservative across versions.
- **First-class project-mode init** (e.g. `vibekit init` style helper that
  picks scope, mode, and settings.local-vs-settings.json).

## v1.0.0 — Stability criteria (not committed)

v1.0.0 is intentionally not scheduled. The bar is conservative and based
on outside signal, not internal confidence. Before tagging v1.0.0:

- [ ] Real install/usage feedback from at least a few external users on
      macOS, Linux/WSL, and Windows.
- [ ] Stable install behavior across Windows / macOS / Linux for at
      least one minor cycle (no install regressions filed against the
      preceding two releases).
- [ ] Onboarding docs verified by someone who has never used the kit
      before, end-to-end, on each supported platform.
- [ ] No critical install or hook regressions filed for v0.2.x.
- [ ] Written support and security policy: how to report a vulnerability,
      how response times work, what is in/out of scope.
- [ ] Public examples or write-ups that aren't from the maintainer alone.

Until those land, treat the project as 0.x. Calling it production-ready or
v1 before then would be overclaiming.

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
