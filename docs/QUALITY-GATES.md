# Quality Gates Workflow

A practical workflow for using the four gates around your existing Claude Code
(and optionally Codex CLI) coding sessions. The gates are local workflow
helpers — they surface findings, propose fixes, and apply them only when you
say so. They are not guarantees.

> **Start with `--audit-only`.** Before letting any gate modify files, run it
> in `--audit-only` mode and read the summary. If the findings look right,
> drop `--audit-only`. See `docs/EXAMPLE-RUN.md` for an illustrative shape.

## Overview

```
You write the PRD
   ↓
/hwan-refactor-idea --audit-only    (Gate 1: PRD check)
   ↓
Development (you + AI)
   ↓
/hwan-refactor-code --audit-only    (Gate 2: code review)
   ↓
UI implementation
   ↓
/hwan-refactor-design --audit-only  (Gate 3: UI/UX check)
   ↓
Pre-deployment
   ↓
/hwan-refactor-git --audit-only     (Gate 4: release readiness)
   ↓
You open the PR, merge, deploy
```

PR creation, push, merge, and deploy are **never automatic** in any mode.

## Each gate's internal flow

Every gate runs roughly these phases:

```
Phase 0: Load prior learnings (if any)
   ↓
Phase 1-3: Parallel audit using available skills
           (gstack, BMAD, superpowers, compound-engineering — where installed)
   ↓
Phase 4-5: Synthesize priority plan (P0 / P1 / P2 / P3)
   ↓
Phase 6+: Execute fixes (skipped if --audit-only)
           Test verification and rollback where the project supports it
   ↓
Phase 7+: Capture learnings for next time
```

If a skill is not installed, that part of the audit is skipped. The doctor
script reports which integrations are present.

## When to use which gate

### Gate 1: `/hwan-refactor-idea`

**When:** right after writing your PRD, before any code.
**What it does:** checks PRD structure, surfaces missing edge cases, weak user
type / permission coverage, and value-prop gaps.
**Output:** `SUMMARY.md` in the gate's workflow directory; an updated PRD if
you re-run without `--audit-only`.

### Gate 2: `/hwan-refactor-code`

**When:** mid-development, especially after a sizable change.
**What it does:** code review using whatever review skills are available.
Where the project has tests, it verifies fixes against them; where it does
not, it can propose characterization tests first (superpowers TDD).
**Output:** `SUMMARY.md` with priorities. With execution enabled, atomic
commits per fix and test additions where applicable.

### Gate 3: `/hwan-refactor-design`

**When:** UI is implemented and you are about to call it done.
**What it does:** UX pass with a state coverage matrix (empty / loading /
error / success / disabled across screens), basic accessibility checks.
**Output:** state matrix report. With execution enabled, UI/CSS fixes and
screenshot comparisons where supported.

### Gate 4: `/hwan-refactor-git`

**When:** right before deployment / PR creation.
**What it does:** security review (gstack `/cso`), QA gaps, documentation
completeness, performance pass. Ends with a SHIP / BLOCK verdict that you
decide whether to act on.
**Output:** `SUMMARY.md`. With execution enabled, security fixes, new tests,
updated docs. **Even in execution mode, it does not push, create PRs, merge,
or deploy.**

## Options (all gates)

| Flag | Effect |
|------|--------|
| `--audit-only` | Stop after findings; no file changes, no commits. Recommended for first runs. |
| `--quick` | Minimum viable check; faster but less thorough. |
| `--dry-run` | Preview only; no file changes. |
| `--include-p2` | Apply P2 items too (default applies P0/P1 only when execution runs). |
| `--resume` | Continue from the last incomplete run. |

## Priority classification

| Priority | Meaning |
|----------|---------|
| P0 | Should not merge with this open. Functional bugs, security issues, data-loss risks. |
| P1 | Fix before the next iteration. Performance, accessibility, correctness near misses. |
| P2 | Worth addressing soon. Missing tests, partial coverage, mild duplication. |
| P3 | Informational. Style nits, leftover debug code. |

The gate proposes the classification; you decide whether to agree.

## How safe mode and full mode affect execution

The install mode you picked changes what happens *around* the gate, not what
the gate itself decides. See `docs/SECURITY.md` for the full picture.

- **`commands-only`** — gates run. No hooks. Nothing automatic outside the
  gate itself.
- **`safe`** (recommended) — gates run. Dangerous git commands are blocked
  by a PreToolUse hook. Sessions started on `main`/`master` get a
  `claude/session-*` branch automatically.
- **`full`** — same as `safe`, plus an auto-save / auto-commit hook fires
  after Claude Code edits. The current hook runs `git add -A` and commits
  the entire working tree, including unrelated changes. Most users should
  stay on `safe`.

`--audit-only` is unaffected by mode: it does not modify files in any mode.

## Compound learning

Each session writes notes to `.claude/learnings/{gate}/` for the project, and
optionally to global `~/.claude/learnings/{gate}/`. The next run loads these
as priors so repeated review oversights become easier to catch over time.
Project-level notes take precedence over global ones.

## What the gates do not do

- They do not write features end-to-end.
- They do not push, open PRs, merge, or deploy.
- They do not replace human review on critical changes.
- They do not provide hard correctness guarantees. Treat the SHIP/BLOCK
  verdict from Gate 4 as advice, not policy.
