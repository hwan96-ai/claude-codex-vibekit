# Repository Map

## When To Use This

Use this before changing files so you understand which areas are source
templates, tests, release assets, docs, or local/private workflow data.

## Top-Level Files

- `README.md` and `README.ko.md`: public-facing overview and install path.
- `install.sh` / `install.ps1`: cross-platform installers.
- `doctor.sh` / `doctor.ps1`: readiness and integration checks.
- `uninstall.sh` / `uninstall.ps1`: removal flows.
- `SHA256SUMS`: release checksum manifest.
- `CONTRIBUTING.md`: contribution process, test guidance, doc tone rules.
- `CHANGELOG.md`, `ROADMAP.md`, `LICENSE`: release and project metadata.
- `PUBLIC_PROFILE_AUDIT.md`: portfolio/public-profile audit notes.

## Source Template Directories

- `.claude/commands/`: shipped Claude Code slash-command templates:
  `git-safe`, `hwan-refactor-idea`, `hwan-refactor-code`,
  `hwan-refactor-design`, and `hwan-refactor-git`.
- `.claude/hooks/`: shipped hook templates for dangerous-git blocking,
  session-start behavior, autosave, and autosave payload handling.
- `codex-prompts/`: Codex prompt templates matching the hwan refactor gates.

Do not place generated workflow output under `.claude/`. Only edit `.claude/`
when the task is explicitly about the shipped command or hook templates.

## Documentation Directories

- `docs/`: durable user, maintainer, architecture, quality, security,
  comparison, example, publishing, and internal release-process docs.
- `docs/assets/`: Mermaid diagrams and static image assets used by docs.
- `docs/internal/`: maintainer-facing release-process guardrails.
- `docs/claude/`: shared agent instruction source of truth.
- `docs/solutions/`: documented solutions and reusable workflow learnings when
  captured by Compound workflows.

## Test And Script Directories

- `tests/`: Bash, PowerShell, and Python smoke or behavior tests. Current tests
  cover installer smoke flows, checksum parity, autosave behavior, dangerous git
  blocking, and uninstall anchoring.
- `scripts/`: checksum generation and blob-based checksum helpers.

## CI And Release Evidence

- `.github/workflows/smoke-tests.yml`: CI smoke-test workflow.
- `docs/GITHUB-PUBLISHING.md`: GitHub release checklist and publishing notes.
- `docs/internal/RELEASE-PROCESS.md`: release guardrails from recent cycles.

## Deployment Files

No application deployment configuration is present in the current tree. Release
activity is documented as GitHub tagging, checksum generation, and GitHub
Release publication, not app deployment.
