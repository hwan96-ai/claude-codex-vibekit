# Development Workflow

## When To Use This

Use this when making repository changes, especially documentation, installer,
hook, prompt, or test changes.

## Start From Evidence

Inspect the current tree before editing. At minimum, check:

```bash
git status --short
git branch --show-current
git log -1 --pretty=format:%h
rg --files
```

Use existing docs and scripts as the source of truth. Do not invent supported
frameworks, package managers, commands, integrations, or deployment flows that
are not evidenced by the repository.

## Scope Discipline

For documentation-only tasks, do not edit product or harness runtime behavior.
Keep edits to the requested documentation paths. If a diff unexpectedly includes
source templates, scripts, tests, package manifests, deployment files, or local
task files, stop and report before staging.

When changing installer, doctor, uninstall, hooks, commands, or prompts, update
the relevant docs in the same change and choose tests based on the touched
surface.

## Root Routers

`AGENTS.md` and `CLAUDE.md` should remain concise routers. Avoid duplicating
long instruction bodies in both files. Shared guidance belongs in
`docs/claude/` and should be linked from the routers.

## Tone And Claims

Follow `CONTRIBUTING.md` tone guidance: calm, accurate, and no overclaiming.
Avoid claims that the gates catch every issue or make the workflow fully safe.
The repo positions Vibekit as a local quality-gate layer with human-controlled
push, PR, merge, and deploy decisions.

## Local-Only Files

Do not commit `.codex_task.md`, local workflow state, secrets, environment
files, generated scratch output, or private notes. Keep portfolio-sensitive
context in private docs unless a sanitized public extraction task explicitly
allows moving it elsewhere.
