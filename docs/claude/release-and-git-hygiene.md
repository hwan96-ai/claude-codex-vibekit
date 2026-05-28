# Release And Git Hygiene

## When To Use This

Use this before branching, staging, committing, pushing, preparing releases, or
touching checksum-relevant files.

## Branching

Start work from a clean tree and a task branch. Avoid direct work on `main` or
`master`. The shipped safety hooks are designed to block several destructive git
operations and protect branch hygiene, but agents should still inspect the
branch and status before making changes.

Useful checks:

```bash
git status --short
git branch --show-current
git log -1 --pretty=format:%h
```

## Staging And Commits

Stage only files in the requested scope. For scoped documentation tasks, verify
with:

```bash
git diff --name-only
git diff --check
```

Do not stage `.codex_task.md`, `.env*`, local workflow state, generated scratch
files, or private notes. If unexpected files appear, stop and report before
committing.

## Release Files

Release-relevant files are governed by `SHA256SUMS`, the checksum scripts, and
the release checklist. If installer, doctor, uninstall, hook, command, or other
release-relevant files change, follow the checksum guidance in
[testing-and-validation.md](testing-and-validation.md) and
[../internal/RELEASE-PROCESS.md](../internal/RELEASE-PROCESS.md).

## Push, PR, Merge, Deploy

The repository docs explicitly preserve human control over push, PR creation,
merge, and deploy decisions for the Vibekit quality-gate workflow. Agents may
perform git operations only when the task asks for them and the current scope is
verified.

## Release References

- [GitHub publishing checklist](../GITHUB-PUBLISHING.md)
- [Release process guardrails](../internal/RELEASE-PROCESS.md)
- [Security and install modes](../SECURITY.md)
