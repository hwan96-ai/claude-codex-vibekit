# Project Overview

## When To Use This

Use this when you need orientation before editing docs, scripts, hooks, prompts,
or tests in this repository.

## What This Repository Is

`claude-codex-vibekit` is a local quality-gate workflow for Claude Code users,
with Codex CLI support as optional companion tooling. The public-facing docs
describe a PRD -> Code -> Design -> Release workflow, audit-only modes, local
safety hooks, doctor checks, and release checksum verification.

The repository is a harness/tooling project. It ships:

- Claude Code slash-command templates under `.claude/commands/`.
- Claude Code hook templates under `.claude/hooks/`.
- Codex prompt templates under `codex-prompts/`.
- Bash and PowerShell installers, doctors, uninstallers, smoke tests, and
  checksum generators.
- Documentation for installation, security, architecture, quality gates,
  comparison, examples, and release process.

## What This Repository Is Not

This is not an application server, frontend app, hosted service, or autonomous
agent that ships work end to end. The existing docs repeatedly preserve a human
handoff: users decide whether to push, open PRs, merge, or deploy.

No root package-manager manifest is present in the current tree. Node.js is
documented as a prerequisite for external tooling such as BMAD and many gstack
helpers, and npm appears in optional Codex installation instructions, but this
repo itself is primarily shell, PowerShell, Python, Markdown, and static assets.

## Architecture From Repository Evidence

The current architecture is layered:

- User decisions and PRD scope at the top.
- Quality-gate slash commands for idea, code, design, and release review.
- Optional external skill providers such as gstack, BMAD, superpowers, and
  compound-engineering where installed.
- Safety hooks for dangerous git detection, session-start branch safety, and
  optional autosave.
- Claude Code and optional Codex CLI as the execution surfaces.

See [repository-map.md](repository-map.md) for file locations and
[development-workflow.md](development-workflow.md) for how to change them.

## Supported Platforms And Shells

Repository evidence shows support for Bash on macOS/Linux/WSL and Windows
PowerShell. Paired files generally exist as `.sh` and `.ps1` variants:
installer, doctor, uninstall, checksum generation, and smoke tests.

## Product Behavior Boundary

Harness-documentation tasks must not change installer, hook, prompt, checksum,
test, or release behavior unless the task explicitly asks for that. For doc-only
changes, keep edits to documentation paths and validate the changed scope before
committing.
