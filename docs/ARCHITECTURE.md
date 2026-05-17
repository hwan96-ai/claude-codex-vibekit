# Architecture

## Design philosophy

Vibe coding is a powerful but risky workflow. This kit adds **structured verification at 4 critical decision points** without slowing down the natural AI-coding flow.

Core principles:
1. **You write specs, AI writes code, gates verify quality**
2. **Auto-execute identified fixes, never auto-develop new features**
3. **Test-driven safety where possible, characterization tests where not**
4. **Compound learning across sessions** — past findings become priors, so repeated mistakes become easier to catch over time
5. **Human always decides merge/deploy** (no exceptions)

## System layers

```
┌─────────────────────────────────────────────────┐
│  Layer 4: You (decisions)                       │
│  Write PRD. Approve plans. Merge PRs.           │
└─────────────────────────────────────────────────┘
                       ↕
┌─────────────────────────────────────────────────┐
│  Layer 3: Quality Gates (orchestration)         │
│  /hwan-refactor-idea, code, design, git         │
│  Each runs audit → plan → execute → learn       │
└─────────────────────────────────────────────────┘
                       ↕
┌─────────────────────────────────────────────────┐
│  Layer 2: Skill providers (specialized tools)   │
│  ┌────────┬────────┬─────────────┬───────────┐  │
│  │ gstack │ BMAD   │ superpowers │ compound  │  │
│  └────────┴────────┴─────────────┴───────────┘  │
└─────────────────────────────────────────────────┘
                       ↕
┌─────────────────────────────────────────────────┐
│  Layer 1: Safety hooks (always-on guardrails)   │
│  block-dangerous-git, auto-save, session-start  │
└─────────────────────────────────────────────────┘
                       ↕
┌─────────────────────────────────────────────────┐
│  Layer 0: Claude Code / Codex CLI               │
└─────────────────────────────────────────────────┘
```

## Each gate's internal pipeline

```
/hwan-refactor-* invoked
   │
   ├─ Phase 0: Load priors
   │  └─ Read .claude/learnings/{gate}/learnings.md
   │     Apply as priors to reduce false positives
   │
   ├─ Phase 1-3: Parallel audit
   │  ├─ Skill 1 (e.g., gstack /review)
   │  ├─ Skill 2 (e.g., bmad-code-review)
   │  ├─ Skill 3 (e.g., adversarial-review)
   │  └─ Skill 4 (e.g., edge-case-hunter)
   │     [All run in parallel via Task tool]
   │
   ├─ Phase 4-5: Synthesize plan
   │  ├─ Merge findings (dedupe across skills)
   │  ├─ Classify P0/P1/P2/P3
   │  ├─ Build dependency DAG
   │  └─ Write SUMMARY.md
   │
   ├─ Phase 6+: Execute (unless --audit-only)
   │  ├─ Pre-check: branch, tests baseline
   │  ├─ For each group:
   │  │  ├─ Parallel: items without conflicts
   │  │  ├─ Each item: snapshot → fix → verify → commit/rollback
   │  │  └─ Post-check: group completion
   │  └─ Final: full test sweep
   │
   └─ Phase 7+: Capture learnings
      └─ Append to .claude/learnings/{gate}/learnings.md
         - False positives observed
         - True positives confirmed  
         - Rollback patterns
         - Project-specific context
```

## Compound learning loop

Each session contributes to `.claude/learnings/{gate}/learnings.md`:

```markdown
## Learning: payment.py race warning is false positive
- Date: 2026-05-20
- Category: false_positive
- Pattern: Concurrent access warnings in payment.py
- Action: De-prioritize to P2 (queue system handles ordering)
- Evidence: PR #123, queue.py provides serialization
- Confidence: 9/10 (5 sessions confirmed)
```

Next session loads these as priors → faster, fewer false positives.

## Why these specific gates?

Each gate maps to a critical decision point in product development where mistakes are expensive:

| Gate | Mistake cost | Why this gate |
|------|--------------|---------------|
| PRD | Whole product fails | Validate gaps before any code |
| Code | Days of refactoring | Catch issues mid-flight |
| Design | User churn | Audit UX state coverage |
| Release | Production incidents | Last-line security/QA check |

Skipping a gate is fine for low-risk changes. The system is opt-in per gate.

## What gets auto-executed vs human-required

| Action | Auto | Human |
|--------|------|-------|
| Identify problems | ✅ | |
| Plan fixes | ✅ | |
| Apply fixes (verified) | ✅ | |
| Add tests | ✅ | |
| Update docs | ✅ | |
| Create commit | ✅ | |
| Branch creation | ✅ | |
| Run test suite | ✅ | |
| **Push to remote** | ❌ | ✅ |
| **Create PR** | ❌ | ✅ (Gate 4 drafts body, user creates) |
| **Merge to main** | ❌ | ✅ (always) |
| **Deploy** | ❌ | ✅ (always) |

## Failure modes & safety

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Test regression from fix | Auto (test suite) | Auto rollback (git stash) |
| Build breaks | Auto (build run) | Auto rollback |
| Visual regression | Auto (screenshot diff) | Auto rollback |
| Security regression | Auto (/cso re-audit) | Block, halt |
| Direct main edit | Auto (git hook) | Block before execution |
| Force push | Auto (git hook) | Block, suggest safer alternative |
| Plan-execution mismatch (>30 files in 1 fix) | Auto | Halt, ask user |

## Integration points

### gstack (Layer 2)
gstack skills used where available: `/review`, `/investigate`, `/cso`, `/qa-only`, `/plan-*`, `/benchmark`, `/document-release`. Other gstack skills may be invoked opportunistically; none are hard requirements.

### BMAD (Layer 2)
34+ workflows used: bmad-prd, bmad-review-adversarial-general, bmad-review-edge-case-hunter, bmad-code-review, bmad-create-ux-design, bmad-qa-generate-e2e-tests

### superpowers (Layer 2)
test-driven-development (critical for Code Gate), systematic-debugging, verification-before-completion, requesting-code-review

### compound-engineering (Layer 2)
ce-compound, ce-sessions for learning persistence (Codex side)

## File system layout

```
~/.claude/                         (global)
├── commands/                      slash commands
│   ├── git-safe.md
│   └── hwan-refactor-*.md (4 files)
├── hooks/                         git safety
│   ├── block-dangerous-git.py
│   ├── auto-save.sh
│   └── session-start.sh
├── skills/
│   └── gstack/                    external (manually installed)
├── learnings/                     compound learning (auto-created)
│   ├── idea/learnings.md
│   ├── code/learnings.md
│   ├── design/learnings.md
│   └── git/learnings.md
└── settings.json                  config (hooks registered here)

<project>/.claude/                 (per-project, auto-created)
├── workflow/                      session artifacts
│   ├── gate-prd-2026-05-20-001/
│   │   ├── SUMMARY.md
│   │   ├── fixes/
│   │   └── state.json
│   └── ...
└── learnings/                     project-specific learnings
    ├── idea/learnings.md
    └── ...
```

Global `~/.claude/learnings/` and per-project `<project>/.claude/learnings/` both exist. Project learnings take precedence (specific > general).
