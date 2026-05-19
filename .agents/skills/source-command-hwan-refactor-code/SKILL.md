---
name: "source-command-hwan-refactor-code"
description: "Refactor Gate - validate code structure mid-development (gstack + BMAD)"
---

# source-command-hwan-refactor-code

Use this skill when the user asks to run the migrated source command `hwan-refactor-code`.

## Command Template

# Purpose
**Gate 2: Refactor Gate.** Use during development when code is getting complex or before/after refactoring. Validate code structure, refactoring needs, hidden bugs, test gaps, separation of concerns.

# Arguments
- No arg: deep mode (parallel full review)
- `--quick`: minimum check (`/review` + `bmad-code-review` only)
- `--scope <path>`: limit review to specific directory/module
- `--investigate <issue>`: jump straight to root-cause analysis for a specific problem
- `--audit-only`: stop after audit + plan, do not execute fixes
- `--dry-run`: preview changes without modifying files
- `--include-p2`: include P2 items in execution (default: only P0/P1)
- `--resume`: resume from last incomplete execution

# Recommended Model
**Codex Opus** for this command. The adversarial and edge-case prompts below use structured output schemas and severity rubrics that benefit significantly from Opus's deeper reasoning.

# Prerequisites

**Installation paths** (Windows):
- gstack 글로벌: `~/.Codex/skills/gstack` (global install)
- gstack 프로젝트별 (팀 모드): `<project>/.Codex/skills/gstack`
- BMAD: `npx bmad-method install` 한 번 실행 (NPM 패키지)

- **gstack** installed
- **BMAD** installed
- Currently NOT on main/master (git hooks should enforce this)
- Working tree state: clean OR all changes committed (for diff-based review)

# Execution

## Phase 0: Load prior learnings (compound learning)

Before starting, check if this Gate has accumulated learnings from previous sessions:
- Read `.Codex/learnings/code/learnings.md` if exists
- Present learnings to Codex as priors:
  - **Known false positives**: Patterns previously flagged but turned out to be intentional → de-prioritize these
  - **Known true positives**: Patterns that always need fixing → prioritize these
  - **Repeated rollback reasons**: Mistakes that caused regressions before → avoid these patterns
  - **Project-specific context**: Special conventions, third-party constraints, etc.

If no learnings file exists, this is a fresh start — that's fine.

These learnings inform downstream phases but **don't override user judgment**. Always show the user what learnings are being applied.


## Phase 1: Safety setup (sequential)

### 1a. Activate `/guard` (gstack)
`/careful` + `/freeze` 활성화. 검증 중 위험한 명령 차단 + 의도하지 않은 파일 수정 방지.

If `--scope` provided: freeze only that scope.

### 1b. Capture baseline
- 현재 git 상태: `git log --oneline -10`, `git status`, `git diff --stat`
- 테스트 baseline: 가능하면 전체 테스트 실행 결과 저장
- LOC, 파일 수, 복잡도 지표 (가능하면)

Save to: `.Codex/workflow/gate-code-{YYYY-MM-DD}-{NNN}/baseline/`

## Phase 2: Codebase health check

Since gstack doesn't have `/health`, derive equivalent from these signals:
- 테스트 통과율
- 최근 커밋의 변경 범위
- TODO/FIXME 카운트
- 큰 파일/큰 함수 식별
- 순환 의존성 (감지 가능 시)

Output: `.Codex/workflow/gate-code-{session}/health-summary.md`

## Phase 3: Multi-perspective parallel review

**`--quick` 모드면 `/review` + `bmad-code-review` 만 실행하고 Phase 5로**

**Use Task tool to fire in parallel (deep mode):**

| Skill | Source | Tier | Focus |
|-------|--------|------|-------|
| `/review` | gstack | S | **코드 리뷰 핵심** - 프로덕션 터질 버그, 완전성 갭 |
| `bmad-code-review` | BMAD | S | BMAD 관점 코드 리뷰 (2차 의견) |
| `bmad-review-adversarial-general` | BMAD | A | **코드 구조/테스트/회귀 관점**에서 변경이 왜 위험한지 |
| `bmad-review-edge-case-hunter` | BMAD | A | **코드 분기, 상태 전이, 실패/재시도/취소** 케이스 |

Each saves to: `.Codex/workflow/gate-code-{session}/reviews/{skill}.md`

**Adversarial 프롬프트 (Gate 2 - 코드 공격)**:

```
역할: 시니어 엔지니어가 이 리팩토링을 공격적으로 비판한다.

대상: {changed_files} (또는 --scope 지정 경로)
변경 diff: {git_diff}

다음 7개 카테고리에서 위험 요소 탐색:
1. **과한 추상화** (인터페이스만 늘고 가치 없음, premature abstraction)
2. **책임 분리 실패** (한 클래스/함수가 너무 많은 일, Single Responsibility 위반)
3. **기존 동작 변경 위험** (구 API 사용자 깨짐, behavior breaking change)
4. **숨은 회귀** (테스트로 잡히지 않을 동작 변화)
5. **성능 회귀** (O(N) → O(N²), N+1 query, 불필요한 IO)
6. **동시성 문제** (race condition, deadlock, shared state without lock)
7. **에러 처리 누락/약화** (catch만 하고 swallow, 의미 잃은 fallback)

각 발견사항 출력 형식 (필수):
- **category**: [위 7개 중]
- **location**: file:line (정확한 위치)
- **problem**: 1-2문장
- **attack_scenario**: 어떤 입력/조건에서 터질지 (구체적)
- **impact**: 사용자/시스템 영향 (예: "결제 중 더블 차지")
- **severity**: P0 | P1 | P2 | P3
- **evidence**: 코드 인용 (3-5줄, 정확히 file:line 표기)
- **fix_direction**: 1-2문장 수정 방향

심각도 기준:
- P0: 프로덕션 데이터 손상/장애 가능 (예: race condition 결제, 권한 우회)
- P1: 회귀 가능성 높음 + 영향 큼 (핵심 플로우)
- P2: 코드 품질/유지보수성 (직접적 장애 X)
- P3: 스타일/일관성

엄격한 규칙:
- 코드 인용 없는 모호한 비판 금지 ("고려해보세요" X)
- file:line 정확히 표기 (file.py:42 형식)
- 카테고리당 최대 3개 (가장 위험한 것만)
- 추측이면 명시 ("추정", "확인 필요" 라벨)

응답 마지막 필수:
- self_confidence: 1-10 (분석 확신도)
- blind_spots: 코드를 다 못 본 영역 (예: "외부 의존성 동작 가정")
- recommended_tests: 발견한 이슈를 잡을 수 있는 테스트 시나리오 3개
- regression_risk_summary: 이 변경의 전체 회귀 위험 한 줄
```

**Edge-case 프롬프트 (Gate 2 - 코드 누락 탐지)**:

```
역할: QA 엔지니어 + SRE가 이 코드의 unhandled case를 모두 찾는다.

대상: {changed_files}

다음 8개 카테고리 모두 점검 (체크리스트):
1. **분기 누락**: if/else, switch에서 빠진 case
   - default 없음, enum 누락, falsy value 동일 처리
2. **상태 전이 미정의**: 상태머신의 빠진 전환
   - 같은 상태 재진입, 역방향 전환, 동시 전환
3. **실패 처리**:
   - 외부 API 5xx/4xx/타임아웃
   - DB 연결 실패, 트랜잭션 롤백
   - 파일 I/O 실패
4. **재시도/멱등성**:
   - 재시도 정책 없음
   - 멱등성 보장 안 됨 (같은 요청 2번 시 중복 실행)
   - 부분 실패 시 일관성 깨짐
5. **취소/타임아웃**:
   - 긴 작업의 취소 신호 무시
   - 타임아웃 후 cleanup 안 됨
6. **동시성**:
   - 공유 변수 락 없이 접근
   - read-modify-write 비원자적
   - 캐시 stampede
7. **null/empty/극단값**:
   - null 체크 누락
   - 빈 배열/문자열 처리
   - 음수, 0, Infinity, NaN
   - 매우 큰 입력 (메모리 폭발)
8. **국제화/시간대**:
   - UTC vs local time 혼용
   - DST 처리
   - locale별 정렬/포맷

각 발견사항 출력 형식 (필수):
- **category**: [위 8개 중]
- **location**: file:line
- **missing_handling**: 어떤 케이스가 처리 안 됨
- **trigger_input**: 이 케이스를 발생시키는 구체적 입력
- **what_happens**: 현재 코드가 어떻게 동작하나 (crash? wrong result? silent fail?)
- **severity**: P0 | P1 | P2 | P3
- **suggested_fix**: 처리 방법 (코드 스니펫 가능)
- **suggested_test**: 이 케이스를 잡을 단위 테스트

심각도 기준:
- P0: 데이터 손상, 보안 우회, 결제 오류 등
- P1: 사용자에게 보이는 에러/오동작
- P2: 로그 노이즈, 성능 저하
- P3: 거의 발생 안 하지만 이론적으로 가능

엄격한 규칙:
- "고려해보세요" 금지, 구체적 입력/조건만
- file:line 정확히
- 같은 함수에서 여러 발견 시 가장 심각한 것 + 패턴 요약
- 너무 광범위한 발견 ("모든 에러 처리 필요") 금지

응답 마지막 필수:
- coverage_score: 1-10 (코드의 견고성)
- top_5_critical_gaps: 가장 치명적인 누락 5개
- pattern_observations: 반복되는 패턴 (예: "전반적으로 타임아웃 처리 누락")
- recommended_test_files: 추가/보강할 테스트 파일 목록
```

## Phase 4: Root cause investigation (conditional)

If reviewers identify unexplained bugs OR `--investigate <issue>` 제공:
- gstack `/investigate` OR BMAD `bmad-investigate` 실행
- 한 번에 한 이슈씩 (병렬 X — 디버깅은 집중 필요)
- Output: `.Codex/workflow/gate-code-{session}/investigations/{issue-id}.md`

## Phase 5: Synthesis with P0/P1/P2/P3

Create `.Codex/workflow/gate-code-{session}/SUMMARY.md`:

```markdown
# Refactor Gate 검증 결과

## 판정
{🟢 GOOD / 🟡 REFACTOR NEEDED / 🔴 BLOCKING ISSUES}

## 통합 이슈 리스트

### P0 (수정 안 하면 회귀/장애)
1. [출처: review, adversarial] {파일:라인} — {문제} → {수정안}
2. ...

### P1 (강력 권장 리팩토링)
- 과한 추상화: {위치}
- 책임 분리 실패: {위치}
- 테스트 누락: {모듈}

### P2 (코드 품질)
- 네이밍, 일관성, 가독성

### P3 (참고)
- 장기 개선 후보

## 추가 산출물
- 리팩토링 포인트 (구체적 위치 + 변경 방향)
- 버그 원인 분석 (investigate 결과)
- 테스트 추가 후보 + 우선순위
- 회귀 위험 영역
```


## Phase 6: Execute code fixes

### 6a-prelude. TDD-first safety (superpowers integration)

**Before applying each fix**, use the `test-driven-development` skill from superpowers plugin.

For each item:
1. **Check test coverage** of the file/function being modified
2. **If no test exists**:
   - Use `test-driven-development` to write a **characterization test** that captures the CURRENT behavior of the affected code
   - Run the test — it should PASS (because code currently works as-is)
   - This test now acts as a **regression detector**
3. **Apply the fix** as planned
4. **Run the characterization test**:
   - PASS → Fix didn't change behavior we wanted to preserve → COMMIT
   - FAIL → Fix changed behavior beyond intent → Ask user: was this the intended change?
     - If yes → update test (the new behavior is what we want)
     - If no → ROLLBACK

**Why this matters**: Without prior tests, regressions are invisible. With TDD-first, every fix is verified against current behavior — even in untested codebases. This solves the "test 없으면 안전망 약함" problem.

**Tradeoff**: Writing characterization tests adds time per item. For trivial changes (typo fixes, comments), this can be skipped with `--no-tdd`.



`--audit-only` flag가 있으면 이 phase는 skip.

### 5a. Pre-execution
- 현재 브랜치 NOT main/master 확인
- 작업 트리 clean (또는 모든 변경 commit됨)
- 테스트 러너 감지 (pytest, jest, vitest 등)
- 전체 테스트 실행, baseline 저장: `.Codex/workflow/gate-code-{session}/baseline.txt`

**Halt unconditionally if baseline broken** (--yolo여도). 사용자가 baseline 깨진 상태로 시작하길 원하는지 명시적 확인.

### 5b. Parse plan into execution groups
SUMMARY.md의 P0/P1 항목 (--include-p2면 P2까지) 추출. 각 항목:
- file:line / 영역
- 변경 방향
- 검증 방법 (특정 테스트, 동작 확인)

**Dependency analysis**:
- 같은 파일 수정하는 항목들은 같은 그룹의 순차 실행
- 다른 파일 수정 항목들은 병렬 가능
- Group A: 독립 항목들 (즉시 병렬 실행)
- Group B: A 완료 후 가능한 항목들
- ...

### 5c. Execute groups
For each group A → B → C → D:

**Pre-check**: 이미 완료된 항목 skip (state.json 확인)

**Parallel dispatch**: Use Task tool to fire all group items in ONE response.

Each Task:
1. **Snapshot**: `git stash push -u -m "pre-{item-id}"`
2. **Apply fix**: 계획서의 변경 방향대로 코드 수정
3. **Item-specific verification**:
   - 지정된 단위 테스트 실행
   - manual check 명시되면 결과 기록
4. **Full test suite**: baseline과 비교
5. **Decision**:
   - ✅ 통과 + 회귀 없음 → COMMIT: `refactor(code): {item_id} {title}\n\nResolves: {ids}\nFrom: {source skills}`
   - ❌ 실패 또는 회귀 → ROLLBACK: `git stash pop` (또는 `git restore .`)
     - **`git clean -f` 사용 금지** (글로벌 훅이 차단)
   - 항목을 failed로 표시, 다른 항목 진행
6. **Log**: `.Codex/workflow/gate-code-{session}/fixes/{item-id}.md`
7. **State update**: state.json 진행상황 저장

**Conflict prevention**: 같은 파일 수정 항목이 있으면 자동 순차 전환.

**Post-check**:
- 모두 성공 → 다음 그룹
- 부분 실패 → 사용자에게 묻기 (계속/중단/재시도)
- 50%+ 실패 → 무조건 STOP

### 5d. Final test sweep
모든 그룹 완료 후 전체 테스트 한 번 더 실행. baseline과 비교. 통과율 떨어졌으면 WARN.

### 5e. Dry-run mode
`--dry-run`이면 각 항목의 변경 미리보기, 실제 수정 X.

### Halt conditions (강제 중단)
- 테스트 baseline 깨짐 (시작 전)
- 한 그룹 50%+ 실패
- 한 항목이 30+ 파일 수정 시도 (계획 오해 가능)
- main/master 수정 시도
- 의존성 사이클


## Phase 7: Capture compound learnings

After execution completes (or even if --audit-only), capture what was learned this session.

### 7a. Analyze session outcomes
From state.json and execution logs, identify:
- **Successfully applied fixes**: Item → reason it worked
- **Rolled back items**: Item → why it failed (regression? wrong fix? user disagreed?)
- **Skipped by user**: Item → why user said no
- **Recurring patterns**: Same type of issue flagged multiple times (signal of false positive or project-specific norm)

### 7b. Extract learnings (structured)
Generate new entries for `.Codex/learnings/code/learnings.md` in this format:

- Learning title (short)
- Date / source session
- Category: false_positive | true_positive | rollback_pattern | project_context
- Pattern: what to look for
- Action: what to do when seeing this pattern
- Evidence: file/PR/commit demonstrating this
- Confidence: 1-10

### 7c. Append to persistent store
- Path: `.Codex/learnings/code/learnings.md`
- Append (don't overwrite) — preserve history
- Also append to `.Codex/learnings/index.md` (global overview)

### 7d. Optional: Register with gstack /learn
If gstack `/learn` is available, register globally for cross-gate visibility.

### 7e. Report what was learned
Tell the user explicitly what learnings were added this session and where they're stored.


# Final Report (Korean)

```
{🟢/🟡/🔴} Refactor Gate 검증 완료

세션: gate-code-{date}-{nnn}
실행 시간: {elapsed}
스코프: {전체 / 지정 경로}

📋 판정: {GOOD / REFACTOR NEEDED / BLOCKING}

📊 이슈 통계:
   P0 (장애/회귀): {N}개
   P1 (리팩토링 권장): {N}개
   P2 (품질): {N}개
   P3 (참고): {N}개

🔍 영역별 결과:
   ✅ gstack /review     : {핵심 발견}
   ✅ BMAD code-review   : {핵심 발견}
   ⚔️ Adversarial       : 위험한 변경 {N}건
   🎯 Edge cases        : 누락 케이스 {N}개
   {🔬 Investigation    : {root cause}} (실행 시)

🧪 테스트 갭:
   - 추가 필요: {N}개 테스트
   - 우선 추가: {top 3 모듈}

🚀 다음 단계:
   {GOOD 시} → 계속 개발 또는 /hwan-refactor-design (UI 단계)
   {REFACTOR NEEDED 시} → P0/P1 이슈 처리 후 재실행
   {BLOCKING 시} → P0 이슈 즉시 처리 필수


────────────────────────────────────────
실행 결과 (Execute Phase)
────────────────────────────────────────
{✅ 완료 / ⚠️ 부분 / 🛑 중단 / ⬜ 스킵 (audit-only)}

📝 코드 수정 적용:
   Group A: ✅ {a_done}/{a_total}
   Group B: ✅ {b_done}/{b_total}
   Group C: ⚠️ {c_done}/{c_total}
   
📝 커밋: {N}개
🔧 수정 파일: {N}개  (+{insertions} -{deletions})

🧪 테스트:
   - 시작: {pass}/{total}
   - 종료: {pass}/{total}
   - 자동 롤백된 회귀: {N}건

❌ 실패 항목:
   - {item_id} {title}
     사유: {reason}
     로그: .Codex/workflow/gate-code-{session}/fixes/{item-id}.md
     → 수동 처리 필요

────────────────────────────────────────
🧠 Compound 학습 (이번 세션)
────────────────────────────────────────
새로 추가된 학습: {N}개
  - {learning_1}
  - {learning_2}
  - {learning_3}

전체 누적 학습: {total_N}개
저장 위치: .Codex/learnings/code/learnings.md

다음 실행 시 자동 적용됩니다.

📁 상세: .Codex/workflow/gate-code-{session}/
   - SUMMARY.md ← 먼저 보세요
   - reviews/ ← 개별 리뷰
   - investigations/ ← root cause 분석 (있는 경우)

ℹ️ /guard 활성화 상태. /unfreeze로 해제 가능.
```

# Mode Reference

| Mode | 실행 내용 | 예상 시간 |
|------|----------|----------|
| `--quick` | /guard + /review + bmad-code-review | 5-8분 |
| (기본/deep) | 위 + 4개 병렬 리뷰 + investigation | 15-25분 |

# 범용 기능 재사용 규칙 (이 Gate에서)
- `bmad-review-adversarial-general` → **코드 구조/테스트/회귀** 관점 공격
- `bmad-review-edge-case-hunter` → **분기/상태/실패** 케이스 누락 탐지
- `/review` → **코드 리뷰 핵심** (이 Gate의 메인 도구)
- `/investigate` → **버그 root cause** 분석

# Notes
- **자동 수정 안 함** — 이슈만 식별. 수정은 사용자가 결정 후 진행
- `--scope`로 부분만 검토 가능 (큰 프로젝트에서 유용)
- 같은 영역 여러 번 검토 가능 (매번 새 세션)
- 종료 시 /guard 유지 (사용자가 직접 /unfreeze)
