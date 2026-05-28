# Security And Secrets

## When To Use This

Use this whenever a task touches install modes, hooks, public docs, portfolio
presentation, generated examples, logs, prompts, or any content that might leak
private operational details.

## Non-Disclosure Rules

Agents must not expose:

- Secrets or credentials.
- Private keys, tokens, API keys, or signing material.
- Private workflow notes.
- Private prompts.
- Internal URLs.
- Non-public automation details.
- Environment files or local task files.

Do not copy sensitive values into examples, docs, commits, issues, PR bodies, or
release notes. Placeholder names such as `OPENAI_API_KEY` may appear in safety
documentation when the context is clearly about detection rules, but do not add
real-looking secrets.

## Install-Scope Sensitivity

Repository docs describe global and project-scoped Claude Code installs.
Global `~/.claude` hooks affect every Claude Code session on the user account.
Project-scope installs affect only the current project and write local settings.
Keep that distinction visible when editing installation or security docs.

## Hook And Autosave Risk

The `safe` mode adds safety hooks but does not enable autosave. The `full` mode
enables autosave/autocommit behavior and is documented as power-user mode. Keep
warnings explicit: autosave can stage more than the user intended if used on a
dirty tree.

## Public Disclosure Boundary

This repository is private, restricted, or portfolio-sensitive. Do not make the
original repository public to create a portfolio artifact. Public showcase work
requires a separate sanitized repository. See
[portfolio-showcase-rules.md](portfolio-showcase-rules.md).

## Security Docs

Use the existing [security document](../SECURITY.md) as the user-facing source
for install modes, hook behavior, checksum verification, and vulnerability
reporting guidance.
