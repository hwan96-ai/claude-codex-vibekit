# Portfolio Showcase Rules

## When To Use This

Use this when describing the project publicly, preparing profile material,
planning a showcase, or deciding whether content can leave this private or
portfolio-sensitive repository.

## Repository Status

Treat this repository as private, restricted, or portfolio-sensitive even when
some docs are written in a public-facing style. The current task scope is
harness engineering for coding agents, not public-release cleanup.

## Public Extraction Rule

Future public portfolio or showcase extraction must happen in a separate
sanitized repository. Do not make this original repository public as a shortcut.
Do not push private workflow notes, private prompts, internal URLs, non-public
automation details, local task files, or secrets into a public target.

## Sanitization Expectations

Before any public showcase repository exists, it needs an explicit sanitization
pass:

- Remove secrets, credentials, private notes, internal URLs, and non-public
  automation details.
- Remove or rewrite local-only task files and private prompts.
- Verify examples, screenshots, logs, and command output for sensitive strings.
- Preserve the project positioning without overstating safety, autonomy, or
  production readiness.
- Confirm license and attribution choices for the separate public repository.

## Current Public-Profile Evidence

`PUBLIC_PROFILE_AUDIT.md` records that the repo has strong public-facing
developer-tooling positioning and that security vocabulary appears in safety
documentation rather than as exposed credentials. Keep that distinction: do not
remove useful security examples just because they contain placeholder credential
names, but do not add real or private values.
