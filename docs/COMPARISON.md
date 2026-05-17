# How Vibekit compares to other AI coding tools

Short version: **different layer of the stack.** Vibekit is not trying to
replace Cursor, Aider, Cline, or Continue. It is a local quality-gate layer
that sits next to whatever you already use to write code with AI — with a
particular focus on Claude Code workflows.

If a project ships with Vibekit, you can still use any of the tools below to
do the actual coding.

## At a glance

| Tool | Primary job | Where Vibekit fits |
|------|-------------|--------------------|
| **Cursor** | AI-native IDE; helps AI write and edit code in your editor. | Use Vibekit's PRD / code / design / release gates between Cursor sessions and shipping. |
| **Aider** | Terminal pair-programming agent backed by an LLM. | Same idea — Aider writes, Vibekit reviews and gates. |
| **Cline** | Autonomous coding agent for VS Code. | Use Cline to build, Vibekit to gate before merge. |
| **Continue** | Open-source AI dev assistant; chat, autocomplete, and workflow checks in the editor and PRs. | Continue covers parts of the inner loop; Vibekit covers the "is this ready to ship" gates and adds local git safety. |
| **Vibekit** | Local quality gates for AI-assisted coding on Claude Code (optional Codex CLI): PRD, code, design, release. Plus git safety hooks, rollback rules, and per-project learning notes. | This is the layer described in this repo. |

## What "different layer" means

Most of the tools above answer the question **"how do I get the AI to write
this code?"**

Vibekit answers a different question: **"before I ship what the AI wrote, what
should I check?"** It runs four checks:

1. **PRD Gate** — is the spec coherent before any code gets written?
2. **Code Gate** — mid-development, does the change look reasonable, tested
   where possible, and consistent with the rest of the codebase?
3. **Design Gate** — does the UI cover the states it claims to?
4. **Release Gate** — pre-deployment security / QA / docs sweep.

Plus optional git safety hooks so you do not accidentally `reset --hard` a
session, and per-project learning notes so the same review oversights become
easier to catch on the next pass.

## What Vibekit does not do

- It does not write features end-to-end. Use Cursor / Aider / Cline / Continue
  or any other coding assistant for that.
- It does not host a review dashboard, manage a team's review queue, or run in
  CI by default. It is a local kit.
- It does not push, merge, or deploy. Those are human decisions.
- It does not depend on Codex CLI. Codex is optional.

## When to combine them

A workflow that pairs well:

1. Sketch a PRD by hand or with help from any tool.
2. Run `/hwan-refactor-idea --audit-only` to gate the spec.
3. Use Cursor / Aider / Cline / Continue (or Claude Code directly) to write
   the code.
4. Run `/hwan-refactor-code --audit-only` mid-development.
5. Run `/hwan-refactor-design --audit-only` once UI is up.
6. Run `/hwan-refactor-git --audit-only` before opening the PR.
7. Open the PR yourself. Merge yourself. Deploy yourself.

If a gate's findings look right, drop `--audit-only` to let it apply fixes.
See `docs/EXAMPLE-RUN.md` for an illustrative shape of that output.
