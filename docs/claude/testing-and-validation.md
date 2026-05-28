# Testing And Validation

## When To Use This

Use this after changing docs, installers, hooks, commands, prompts, tests, or
release files to choose validation that matches the risk.

## Lightweight Documentation Checks

For docs-only changes, run:

```bash
git diff --check
git diff --name-only
```

Review the changed file list against the task scope. For this harness, doc-only
changes should not include product source, dependency manifests, deployment
files, `.env*`, `.github/**`, or local task files unless explicitly allowed by
the task.

Check relative Markdown links when adding or moving docs. Prefer links that work
from the file's own directory, such as `../` or `../../` as needed.

## Script And Harness Checks

Existing repository evidence supports these checks:

```bash
bash tests/smoke.sh
.\tests\smoke.ps1
bash tests/test-checksums.sh
python tests/test-block-dangerous-git.py
bash tests/test-auto-save.sh
```

For installer or doctor changes, `CONTRIBUTING.md` also documents isolated
`CLAUDE_HOME` install, doctor, and uninstall checks.

## Syntax Checks

For shell changes:

```bash
bash -n install.sh doctor.sh uninstall.sh .claude/hooks/auto-save.sh
```

For PowerShell changes, use the parser check shown in `CONTRIBUTING.md` when
PowerShell is available.

## Checksum Validation

When a release-relevant file changes, regenerate and verify checksums using the
existing scripts:

```bash
bash scripts/generate-checksums.sh --check
.\scripts\generate-checksums.ps1 -Check
```

On Windows, `docs/internal/RELEASE-PROCESS.md` documents blob-based checksum
handling to avoid CRLF working-tree artifacts.

## Completion Standard

Treat green checks as evidence only for the surface they cover. A doc-only
change usually needs link/scope validation and diff review; a hook or installer
change needs smoke and behavior tests.
