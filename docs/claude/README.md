# Claude And Codex Harness Docs

## When To Use This

Use this index at the start of any agent session in this repository. It routes
Claude Code, Codex, and other coding agents to the durable project guidance
without duplicating long instructions in root files.

## Document Set

- [Project overview](project-overview.md) explains what this repo is, what it is
  not, and the architecture inferred from current files.
- [Repository map](repository-map.md) maps the important directories, file
  types, and generated or local-only areas.
- [Development workflow](development-workflow.md) covers how to make scoped
  changes without affecting product behavior.
- [Testing and validation](testing-and-validation.md) lists lightweight and
  broader verification commands already supported by the repo.
- [Security and secrets](security-and-secrets.md) documents disclosure limits,
  install-scope risks, and secret-handling rules.
- [Portfolio showcase rules](portfolio-showcase-rules.md) covers public-profile
  and sanitized-extraction rules.
- [Release and git hygiene](release-and-git-hygiene.md) summarizes branch,
  commit, checksum, and release safety expectations.

## Router Contract

`AGENTS.md` is the Codex and general-agent router. `CLAUDE.md` is the Claude
Code router. This directory is the shared source of truth for durable
instructions.

Keep the routers concise. If a rule applies across tools or future sessions,
put it in this directory and link to it.

## Privacy Baseline

This repository is private, restricted, or portfolio-sensitive. Agents must not
expose secrets, credentials, private workflow notes, private prompts, internal
URLs, or non-public automation details. Any future public portfolio/showcase
extraction must happen in a separate sanitized repository, not by making this
original repository public.
