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

---

## All four gates (illustrative)

Each gate runs the same Phase-0 → Phase-5 shape (load priors → parallel
audit → synthesize plan → write SUMMARY.md → optional apply). Below are
illustrative snippets only. Real findings depend on your project, the
installed skills, and the model.

### 1. PRD Gate — `/hwan-refactor-idea --audit-only`

```markdown
# PRD Gate — audit-only summary
Spec: docs/prd/onboarding-redesign.md

## Findings
### P0
- "Goal" section asserts a 40% conversion lift with no measurement plan.
  Suggested: define baseline, sample size, and success window before build.
### P1
- "Out of scope" missing. Risk of feature creep.
### P2
- Acceptance criteria conflate UX and analytics. Split.
## Files touched: none (audit-only)
```

### 2. Code Gate — `/hwan-refactor-code --audit-only`

See the worked example above. Output lives in `SUMMARY.md`; no edits,
no commits.

### 3. Design Gate — `/hwan-refactor-design --audit-only`

```markdown
# Design Gate — audit-only summary
Surface: src/components/SignupForm.tsx, src/pages/signup.tsx

## State coverage matrix
| State        | Covered | Notes |
|--------------|---------|-------|
| empty        | yes     | placeholder copy ok |
| loading      | no      | P1: spinner missing |
| error        | partial | P0: server error swallowed |
| success      | yes     |       |
| disabled     | no      | P2 |
| a11y focus   | partial | P1: focus ring removed |

## Findings
### P0
- Server error path silently routes to /success. Add error toast + stay on form.
## Files touched: none (audit-only)
```

### 4. Release Gate — `/hwan-refactor-git --audit-only`

```markdown
# Release Gate — audit-only summary
Branch: feat/onboarding-redesign  Base: main  Ahead: 12 commits

## Checks
- secrets scan:   ok
- migration risk: P1 — schema change on users table; no backfill verified
- test coverage:  P2 — new flows have unit tests only, no e2e
- docs:           ok (README + CHANGELOG updated)
- rollback:       P0 — no documented rollback for the auth-cookie change

## Files touched: none (audit-only)
## Recommended: address P0 before opening PR; re-run without --audit-only.
```

## How to interpret PARTIAL from doctor

`doctor.sh` / `doctor.ps1` end with one of three verdicts. `PARTIAL` is
**not a failure** — it usually means "the core works; some optional pieces
aren't wired up yet." Common causes:

- You chose `--mode commands-only`, so safe-mode hooks aren't configured.
- You haven't installed gstack, BMAD, superpowers, or compound-engineering.
- The Claude Code `/plugins` UI hasn't been used yet on this machine.

Audit-only gate runs still work in PARTIAL. Treat the "recommended next
steps" block at the bottom of doctor's output as a punch list, not as
errors. Only `ACTION REQUIRED` should block you (missing required tool,
missing core command files, or unparseable `settings.json`).

## First 10 minutes

A realistic on-ramp on a toy project. Total: ~10 minutes if your machine
already has git, node 20+, python, and Claude Code.

1. **Clone the kit** (1 min)
   ```bash
   git clone https://github.com/hwan96-ai/claude-codex-vibekit.git
   cd claude-codex-vibekit
   ```
2. **Install** (1 min). Start with `commands-only` if anything about hooks
   makes you nervous, otherwise `safe`:
   ```bash
   ./install.sh --mode commands-only   # or --mode safe
   ```
3. **Run doctor** (30 s). Expect `READY` or `PARTIAL`. If `ACTION REQUIRED`,
   follow the recommended next steps it prints.
   ```bash
   ./doctor.sh
   ```
4. **Open a throwaway project** (2 min). A small repo you don't mind
   touching, or `git init` a temp dir and drop a README.
5. **Run an audit-only gate** (3-5 min). PRD gate is the cheapest to try:
   ```
   /hwan-refactor-idea --audit-only
   ```
6. **Read `SUMMARY.md`** (2 min). Decide whether to fix anything by hand or
   re-run without `--audit-only`.

If something feels wrong, uninstall is one command:
```bash
./uninstall.sh --yes
```
