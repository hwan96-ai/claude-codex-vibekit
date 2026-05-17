# Example run (illustrative)

> **This page is illustrative.** The output below is a mock that shows the
> *shape* of a Code Gate run, not a real result. Actual output depends on the
> project, the skills installed (gstack, BMAD, superpowers,
> compound-engineering), the model you are using, and the changes in your
> working tree. Do not treat the example as a benchmark or a promise.

## What we will run

A mid-development code review on a feature branch, without applying any
fixes:

```
/hwan-refactor-code --audit-only
```

`--audit-only` means: load priors, audit in parallel, synthesize a plan,
write `SUMMARY.md`, **stop**. No file edits, no commits.

## What you might see

Phases reported by the gate (mock):

```
Phase 0: loading priors from .claude/learnings/code/learnings.md
Phase 1-3: parallel audit (4 reviewers)
Phase 4-5: synthesizing priority plan
Phase 6+: skipped (--audit-only)
Phase 7+: capturing session metadata (no learnings yet — audit only)
```

## Example SUMMARY.md shape

```markdown
# Code Gate — audit-only summary

Branch:    claude/session-20260518-101542
Commit:    a3f9c12
Reviewers: gstack /review, gstack /investigate, bmad-code-review,
           superpowers verification-before-completion

## Findings

### P0 — must fix before merge
- src/auth/session.ts:84
  Token refresh swallows network errors. A failed refresh currently
  resolves with the old token, which silently extends a stale session.
  Suggested fix: surface the error to the caller and force re-auth.
  Source: gstack /review, bmad-code-review (independent agreement)

### P1 — fix soon
- src/api/users.ts:142
  N+1 query in /users/:id/posts. Loads posts in a loop per user.
  Suggested fix: single query with JOIN, or DataLoader.
  Source: gstack /investigate
- src/components/UserCard.tsx:33
  Missing accessible label on the avatar button.
  Suggested fix: add aria-label="Open profile menu".
  Source: bmad-code-review

### P2 — consider
- tests/auth.test.ts
  No characterization test for the token refresh path before the
  change. Superpowers recommends adding one before applying P0.
  Source: superpowers TDD

### P3 — informational
- src/utils/logger.ts:12
  Console.log left in. Low priority; remove during cleanup.
  Source: gstack /review

## Priors applied
- payment.py race warning treated as known false positive
  (see .claude/learnings/code/learnings.md, confidence 9/10)

## Next steps
- Re-run without --audit-only to apply P0 and P1 fixes.
- Or hand-fix P0 (token refresh) and re-run for verification.
```

The shape above is what the gate aims for. Actual section names,
classifications, and source attributions will differ based on which skills
are installed and what the model actually finds.

## Finding format

Each finding aims to include:

- file path and line number, when known
- one-sentence description of the issue
- one-sentence suggested fix
- which reviewer raised it

## Priority classification

| Priority | Meaning |
|----------|---------|
| P0 | Should not merge with this open. Functional bugs, security issues, data loss risks. |
| P1 | Fix before the next iteration. Performance, accessibility, correctness near misses. |
| P2 | Worth addressing soon. Missing tests, partial coverage, mild duplication. |
| P3 | Informational. Style nits, leftover debug code. |

The gate decides these; you decide whether you agree.

## Safe mode vs full mode during a real run

With `--mode safe` installed:

- Dangerous git commands are blocked by the PreToolUse hook.
- Session-start branch safety creates a `claude/session-*` branch if needed.
- Nothing else is automatic. The audit-only run reads files and writes
  `SUMMARY.md` only.

With `--mode full` installed:

- Same as `safe`, plus: after any file edit (when not in `--audit-only`), the
  auto-save hook runs `git add -A && git commit -m "autosave: <timestamp>"`.
  This stages and commits the entire working tree, including unrelated
  changes. The current run is `--audit-only`, so no edits happen.

If `full` mode worries you, stay on `safe`. See `docs/SECURITY.md`.

## Caveats again, in plain text

- This document is a mock. Real output will look different.
- Whether you see four reviewers, six reviewers, or one depends on what is
  installed.
- Numbers, file paths, and line numbers above are fabricated for illustration.
