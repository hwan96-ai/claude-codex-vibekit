# Claude Code Router

This repo ships local quality-gate commands, hooks, prompts, docs, and tests
for Claude Code users, with Codex CLI support as optional companion tooling.

Use [docs/claude/README.md](docs/claude/README.md) as the shared instruction
index. The root routers stay short; durable guidance belongs in
`docs/claude/`.

## Task Routing

- Architecture and repository context: [docs/claude/project-overview.md](docs/claude/project-overview.md)
  and [docs/claude/repository-map.md](docs/claude/repository-map.md).
- Local work process: [docs/claude/development-workflow.md](docs/claude/development-workflow.md).
- Test commands and validation gates: [docs/claude/testing-and-validation.md](docs/claude/testing-and-validation.md).
- Secrets, privacy, and safe disclosure: [docs/claude/security-and-secrets.md](docs/claude/security-and-secrets.md).
- Portfolio-safe extraction: [docs/claude/portfolio-showcase-rules.md](docs/claude/portfolio-showcase-rules.md).
- Release and git hygiene: [docs/claude/release-and-git-hygiene.md](docs/claude/release-and-git-hygiene.md).

## Guardrails

- Do not expose secrets, credentials, private workflow notes, private prompts,
  internal URLs, or non-public automation details.
- Do not make this original repository public as a portfolio shortcut. Create a
  separate sanitized showcase repository if public extraction is needed.
- Do not place generated work under `.claude/` unless the task is explicitly
  changing the shipped command or hook templates.
- Do not commit local task files such as `.codex_task.md`.
