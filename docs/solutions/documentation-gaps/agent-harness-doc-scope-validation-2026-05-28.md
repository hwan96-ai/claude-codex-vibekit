---
title: Agent Harness Docs Need Scope And Evidence Validation
date: 2026-05-28
category: docs/solutions/documentation-gaps
module: agent-harness-docs
problem_type: documentation_gap
component: documentation
severity: medium
applies_when:
  - Creating or refreshing AGENTS.md, CLAUDE.md, or shared agent instruction docs
  - Running documentation-only tasks with strict file-scope limits
  - Capturing portfolio-sensitive repository guidance for future agents
tags: [agent-harness, documentation, scope-control, privacy, validation]
---

# Agent Harness Docs Need Scope And Evidence Validation

## Context

The repository needed an agent-harness documentation structure without changing
product behavior. The task had strict file scope, required concise root routers,
and required privacy and portfolio-readiness guidance to be first-class.

## Mistakes

- Treating a newly created untracked file set as reviewable by `git diff`
  without first adding intent-to-add state meant the first diff command showed
  no content.
- A general command-line link checker failed in the Windows sandbox, so link
  validation needed to fall back to smaller `rg --files` checks and manual path
  reasoning.

## Wrong Assumptions

- Do not assume root instruction files already exist. The current tree had no
  tracked `AGENTS.md` or `CLAUDE.md`, so useful router meaning had to be built
  from the task instructions and repository evidence.
- Do not assume package-manager or deployment configuration exists just because
  the repo uses Node-related external tools. The current tree had no root
  package manifest and no app deployment config.

## Failed Attempts

- `Get-ChildItem` and ad hoc PowerShell/Node link-check commands intermittently
  failed with a sandbox spawn-refresh error.
- The reliable fallback was to use `rg --files`, `git diff --check`, and direct
  diff review to validate file presence, references, and changed scope.

## Review Findings

- The repository is a shell, PowerShell, Python, Markdown, and static-asset
  harness project, not an application runtime.
- The durable source of truth belongs under `docs/claude/`; root `AGENTS.md`
  and `CLAUDE.md` should stay concise.
- Public showcase extraction must be documented as a separate sanitized
  repository path, not a visibility change to the original repository.

## Final Solutions

- Added concise root routers for Codex/general agents and Claude Code.
- Added shared `docs/claude/` source documents with a `When To Use This`
  section in every child document.
- Kept instructions evidence-based: no invented app framework, package manager,
  or deployment claims.
- Captured explicit non-disclosure and portfolio-sanitization rules.

## Prevention Rules

- Before claiming completion on harness docs, run `git diff --name-only` and
  compare every changed file against the task's allowed paths.
- Use `git add -N` for newly created docs before reviewing an unstaged diff.
- Document unsupported facts as absent when repository evidence shows absence;
  do not fill gaps with likely defaults.
- Keep privacy rules duplicated only where agents need immediate visibility:
  root routers, the shared docs index, and the dedicated security/portfolio
  child docs.
- If a validation helper fails because of the shell environment, use a narrower
  repo-native check and record the fallback in the final report.

## Related

- [Agent docs index](../../claude/README.md)
- [Development workflow](../../claude/development-workflow.md)
- [Security and secrets](../../claude/security-and-secrets.md)
