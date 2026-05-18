---
description: PRD Gate - validate hand-written PRD before development (gstack + BMAD)
---

# Purpose
**Gate 1: PRD Gate.** User has just written a PRD. Validate structure, product logic, MVP scope, UX flow, technical risks, edge cases — BEFORE any code is written.

User writes the PRD themselves. This command validates it using gstack + BMAD skills.

# Arguments
- No arg: deep mode (parallel full review)
- `--quick`: minimum viable validation (`bmad-prd validate` + `/autoplan` only)
- `--prd <path>`: specify PRD file path (default: search for PRD.md, prd.md, docs/PRD.md)
- `--audit-only`: stop after audit + plan, do not execute fixes
- `--dry-run`: preview changes without modifying files
- `--include-p2`: include P2 items in execution (default: only P0/P1)
- `--resume`: resume from last incomplete execution

# Prerequisites

**Installation paths** (Windows):
- gstack 글로벌: `~/.claude/skills/gstack` (global install)
- gstack 프로젝트별 (팀 모드): `<project>/.claude/skills/gstack`
- BMAD: `npx bmad-method install` 한 번 실행 (NPM 패키지)

- **gstack** installed: `~/.claude/skills/gstack`
- **BMAD** installed: `npx bmad-method install` if missing
- PRD file exists in project (or specified via `--prd`)

# Execution

## Phase 0: Load prior learnings (compound learning)

Before starting, check if this Gate has accumulated learnings from previous sessions:
- Read `.claude/learnings/idea/learnings.md` if exists
- Present learnings to Claude as priors:
  - **Known false positives**: Patterns previously flagged but turned out to be intentional → de-prioritize these
  - **Known true positives**: Patterns that always need fixing → prioritize these
  - **Repeated rollback reasons**: Mistakes that caused regressions before → avoid these patterns
  - **Project-specific context**: Special conventions, third-party constraints, etc.

If no learnings file exists, this is a fresh start — that's fine.

These learnings inform downstream phases but **don't override user judgment**. Always show the user what learnings are being applied.


## Phase 1: Locate and load PRD

- Find PRD file: check `PRD.md`, `prd.md`, `docs/PRD.md`, `docs/prd.md`, or `--prd` argument
- If not found: STOP and ask user for path
- Save copy to session: `.claude/workflow/gate-prd-{YYYY-MM-DD}-{NNN}/prd-snapshot.md`

## Phase 2: PRD structural validation (sequential, must pass first)

### 2a. `bmad-prd validate` (S+ tier)
PRD 구조/완전성 검증. 누락된 섹션, 모호한 표현, 측정 불가 목표 식별.
Output: `.claude/workflow/gate-prd-{session}/bmad-prd-validate.md`

**Halt if PRD is incomplete**: 핵심 섹션(문제, 사용자, 목표, 성공 지표) 누락 시 STOP. 사용자가 PRD 보강 후 다시 실행.

`--quick` 모드: 여기서 `/autoplan` 실행하고 종료.

## Phase 3: Multi-perspective parallel review

**Use Task tool to fire ALL of these in ONE response (parallel):**

| Skill | Source | Tier | Focus |
|-------|--------|------|-------|
| `/plan-ceo-review` | gstack | S | 제품 가치, 시장 위치, MVP 범위 |
| `/plan-eng-review` | gstack | S | 구현 가능성, 기술 리스크, 아키텍처 |
| `/plan-design-review` | gstack | A+ | UX 흐름, UI 일관성 (해당 시) |
| `/plan-devex-review` | gstack | A | API/CLI/SDK 사용성 (해당 시) |
| `bmad-review-adversarial-general` | BMAD | A | **제품/시장/범위 관점**에서 PRD가 왜 실패할 수 있는지 공격적 비판 |
| `bmad-review-edge-case-hunter` | BMAD | A | **요구사항에서 빠진 사용자 유형, 예외 플로우, 정책 분기** 찾기 |

Each saves to: `.claude/workflow/gate-prd-{session}/reviews/{skill}.md`

**Adversarial 프롬프트 (Gate 1 - PRD 공격)**:

```
역할: 시니어 PM / 투자자가 이 PRD를 공격적으로 비판한다.

대상 PRD: {prd_path}

다음 7개 카테고리에서 위험 요소를 탐색하라:
1. 가정 오류 (검증 안 된 가설을 사실처럼 다룸)
2. 시장 진입 어려움 (이미 포화/regulation/유통 채널 부재)
3. 범위 폭주 가능성 (MVP라 하면서 v2 수준의 기능 포함)
4. 가치 제안의 약점 (왜 이걸 선택해야 하는지 불명확)
5. 경쟁사 누락 (대체재 무시 또는 과소평가)
6. 비즈니스 모델 결함 (수익화 경로 불명, 단위경제성 의문)
7. 측정 불가능한 목표 (KPI가 모호하거나 추적 불가)

각 발견사항 출력 형식 (필수, JSON-like markdown):
- **category**: [위 7개 중 하나]
- **prd_section**: 인용할 PRD 섹션/줄
- **problem**: 1-2문장
- **failure_scenario**: 출시 후 어떻게 실패하는지 구체적 시나리오
- **impact**: 사용자/회사에 미치는 영향
- **severity**: P0 | P1 | P2 | P3
- **evidence**: PRD에서 직접 인용 (3-5줄)
- **fix_direction**: 한 문장 수정 방향

심각도 기준:
- P0: 이걸 해결 안 하면 출시 자체 실패 가능 (가치 제안 붕괴, 시장 부재)
- P1: 출시는 가능하나 빠른 죽음 (낮은 채택, 빠른 churn)
- P2: 품질/장기 성장 영향
- P3: 참고

엄격한 규칙 (위반 시 답변 불완전 간주):
- "고려해보세요", "검토 필요" 같은 모호한 비판 금지
- PRD 인용 없는 발견 금지
- 카테고리당 최대 3개 (가장 위험한 것만)
- 같은 PRD 섹션에 여러 발견 시 가장 심각한 것만

응답 마지막 필수:
- self_confidence: 1-10 (이 분석의 확신도)
- blind_spots: 놓쳤을 가능성 있는 영역 2-3개
- recommended_follow_up: 추가 사용자 인터뷰/리서치가 필요한 가설 목록
```

**Edge-case 프롬프트 (Gate 1 - PRD 누락 탐지)**:

```
역할: QA 리드 + 운영 매니저가 이 PRD에서 누락된 시나리오를 모두 찾는다.

대상 PRD: {prd_path}

다음 6개 카테고리를 모두 점검하라 (체크리스트):
1. **사용자 유형 누락**: 표준 사용자 외 누가 더 있나
   - 권한별 (admin/staff/user/guest/anonymous)
   - 상태별 (신규/활성/휴면/탈퇴)
   - 디바이스별 (모바일/태블릿/데스크탑/스크린리더)
   - 지역/언어별 (해당 시)
2. **예외 플로우**: happy path 외 unhappy path
   - 입력 실패, 네트워크 끊김, 타임아웃
   - 결제 실패, 인증 만료, 권한 부족
3. **정책 분기**: 비즈니스 규칙의 분기점
   - 무료/유료 분기, 한도 도달, 약관 동의
   - 지역별 법규 (GDPR, 개인정보보호법 등)
4. **권한 케이스**: 누가 무엇을 볼/할 수 있나
   - 본인/타인 데이터, 공유/비공개, 만료된 토큰
5. **미정의 상태**: 화면/플로우의 빈 상태
   - 데이터 0개, 검색 결과 없음, 첫 사용
6. **운영 케이스**: 배포 후 실제 환경
   - 동시 사용, 데이터 마이그레이션, 백업/복구

각 발견사항 출력 형식 (필수):
- **category**: [위 6개 중]
- **missing_scenario**: 어떤 시나리오가 빠졌는지
- **example_user_action**: 구체적 사용자 행동 예시
- **what_breaks**: PRD대로 만들면 어떻게 깨지는지
- **severity**: P0 | P1 | P2 | P3
- **prd_addition_suggestion**: PRD에 추가할 텍스트 (복붙 가능한 형태)

심각도 기준:
- P0: 이 케이스 빠지면 출시 직후 사용자 컴플레인 또는 법적 리스크
- P1: 일주일 내 발견될 수밖에 없는 갭
- P2: 한 달 내 발견될 갭
- P3: 점진적 발견될 정도

엄격한 규칙:
- "고려해보세요" 금지. 구체적 행동/입력/조건만
- 카테고리당 최소 2개, 최대 5개 발견 (커버리지 확보)
- 너무 명백한 것(예: "에러 메시지 보여주기")은 P3 또는 제외

응답 마지막 필수:
- coverage_score: 1-10 (PRD가 얼마나 케이스를 잘 다루는지)
- top_3_critical_gaps: 가장 치명적인 누락 3개
- recommended_tests: 이런 누락을 잡을 수 있는 테스트 시나리오
```

## Phase 4: Optional deep elicitation

If `--deep` flag (or if any reviewer says "PRD too shallow"):
- `bmad-advanced-elicitation`: PRD 깊이 개선. 답변 안 된 핵심 질문 더 파고들기.

## Phase 5: Synthesis with P0/P1/P2/P3 prioritization

Create `.claude/workflow/gate-prd-{session}/SUMMARY.md`:

```markdown
# PRD Gate 검증 결과

## 판정
{🟢 PASS / 🟡 PASS WITH CONDITIONS / 🔴 FAIL — PRD 보강 필요}

## 통합 이슈 리스트 (모든 리뷰어 결과 종합 + 중복 제거)

### P0 (반드시 PRD에 반영해야 개발 시작 가능)
1. [출처: ceo-review] {이슈} → {수정안}
2. [출처: eng-review] {이슈} → {수정안}
3. [출처: adversarial] {이슈} → {수정안}

### P1 (반영 강력 권장)
...

### P2 (반영하면 좋음)
...

### P3 (참고)
...

## 산출물
- PRD 개선안 (구체적 수정 텍스트 포함)
- MVP 범위 조정 제안
- 누락 요구사항 목록
- 제품 리스크 / UX 리스크 / 기술 리스크
- 엣지케이스 목록
```


## Phase 6: Execute PRD fixes

`--audit-only` flag가 있으면 이 phase는 skip.

### 6a. Pre-execution check
- PRD 파일 존재 확인
- 현재 브랜치 NOT main/master (글로벌 훅 처리)
- PRD 백업: `cp PRD.md .claude/workflow/gate-prd-{session}/PRD.md.before-fix`

### 6b. Parse plan items
SUMMARY.md에서 P0/P1 항목 추출 (`--include-p2`면 P2까지).
각 항목은 다음 정보 포함:
- prd_section: 수정할 PRD 섹션
- current_text: 현재 문구 (인용)
- new_text: 적용할 문구
- reason: 왜 수정하는지

### 6c. Sequential apply (PRD는 순차 수정 권장)
For each item in priority order (P0 → P1 → P2):
1. **Snapshot**: 현재 PRD 상태 백업
2. **Apply edit**: 
   - `current_text`가 PRD에 정확히 있는지 확인
   - 있으면 `new_text`로 교체
   - 없으면 SKIP하고 로그에 기록 (PRD가 이미 다른 상태)
3. **Validate**: `bmad-prd validate`로 재검증 (간단한 sanity check)
4. **Commit**: `refactor(prd): {item_id} {title}\n\nFrom: {source_skill}`
5. **Log**: `.claude/workflow/gate-prd-{session}/fixes/{item-id}.md`

### 6d. Post-fix validation
모든 수정 적용 후:
- 전체 PRD를 `bmad-prd validate`로 재검증
- 새로 P0 이슈 생겼는지 체크 (드물지만 가능)

### 6e. Dry-run mode
`--dry-run`이면:
- 각 항목의 변경 사항 미리보기 (diff 형식)
- 실제 파일 수정 안 함
- 결과를 `.claude/workflow/gate-prd-{session}/dry-run-preview.md`에 저장

### Halt conditions
- PRD 파일 누락 → STOP
- 같은 섹션 5개 이상 수정 시도 → STOP, 사용자 확인 요청
- `current_text` 매칭 실패 50% 이상 → STOP (PRD가 plan과 일치 안 함)


## Phase 7: Capture compound learnings

After execution completes (or even if --audit-only), capture what was learned this session.

### 7a. Analyze session outcomes
From state.json and execution logs, identify:
- **Successfully applied fixes**: Item → reason it worked
- **Rolled back items**: Item → why it failed (regression? wrong fix? user disagreed?)
- **Skipped by user**: Item → why user said no
- **Recurring patterns**: Same type of issue flagged multiple times (signal of false positive or project-specific norm)

### 7b. Extract learnings (structured)
Generate new entries for `.claude/learnings/idea/learnings.md` in this format:

- Learning title (short)
- Date / source session
- Category: false_positive | true_positive | rollback_pattern | project_context
- Pattern: what to look for
- Action: what to do when seeing this pattern
- Evidence: file/PR/commit demonstrating this
- Confidence: 1-10

### 7c. Append to persistent store
- Path: `.claude/learnings/idea/learnings.md`
- Append (don't overwrite) — preserve history
- Also append to `.claude/learnings/index.md` (global overview)

### 7d. Optional: Register with gstack /learn
If gstack `/learn` is available, register globally for cross-gate visibility.

### 7e. Report what was learned
Tell the user explicitly what learnings were added this session and where they're stored.


# Final Report (Korean)

```
{🟢/🟡/🔴} PRD Gate 검증 완료

세션: gate-prd-{date}-{nnn}
실행 시간: {elapsed}

📋 판정: {PASS / 조건부 PASS / FAIL}

📊 이슈 통계:
   P0 (필수): {N}개
   P1 (강력 권장): {N}개
   P2 (권장): {N}개
   P3 (참고): {N}개

🔍 영역별 결과:
   ✅ CEO 리뷰         : {핵심 발견}
   ✅ Eng 리뷰         : 구현 난이도 {S/M/L/XL}, 리스크 {N개}
   {⚠️ Design 리뷰     : 점수 {N}/10} (해당 시)
   {⚠️ DevEx 리뷰      : {핵심 우려}} (해당 시)
   ⚔️ Adversarial    : 치명적 허점 {N}개
   🎯 Edge cases     : 빠진 분기 {N}개

🚀 다음 단계:
   {PASS 시} → /hwan-refactor-code (개발 중 코드 검증)
   {조건부 시} → P0 이슈 PRD에 반영 후 재실행
   {FAIL 시} → PRD 보강 (P0 이슈 처리 필수)


────────────────────────────────────────
실행 결과 (Execute Phase)
────────────────────────────────────────
{✅ 완료 / ⚠️ 부분 / 🛑 중단 / ⬜ 스킵 (audit-only)}

📝 PRD 수정 적용:
   - P0 항목: {p0_done}/{p0_total} 적용
   - P1 항목: {p1_done}/{p1_total} 적용
   - 스킵 (이미 수정됨): {skipped}개
   - 실패 (텍스트 매칭 X): {failed}개

📝 커밋: {N}개
💾 백업: PRD.md.before-fix

🔄 사후 검증:
   - bmad-prd validate 재실행: {pass/fail}
   - 새로 생긴 P0 이슈: {N}개

────────────────────────────────────────
🧠 Compound 학습 (이번 세션)
────────────────────────────────────────
새로 추가된 학습: {N}개
  - {learning_1}
  - {learning_2}
  - {learning_3}

전체 누적 학습: {total_N}개
저장 위치: .claude/learnings/idea/learnings.md

다음 실행 시 자동 적용됩니다.

📁 상세: .claude/workflow/gate-prd-{session}/
   - SUMMARY.md ← 먼저 보세요
   - prd-snapshot.md ← 검증 시점 PRD
   - reviews/ ← 개별 리뷰
```

# Mode Reference

| Mode | 실행 내용 | 예상 시간 |
|------|----------|----------|
| `--quick` | bmad-prd validate + /autoplan | 3-5분 |
| (기본/deep) | 위 + 6개 병렬 리뷰 + 통합 | 10-15분 |

# 범용 기능 재사용 규칙 (이 Gate에서)
- `bmad-review-adversarial-general` → **제품/시장/범위** 관점 공격
- `bmad-review-edge-case-hunter` → **요구사항/사용자/정책** 관점 누락 탐지
- `/plan-eng-review` → **기술 계획/구현 리스크** 보조 (이 Gate에서는 PRD 수준)

# Notes
- **코드 절대 수정 안 함** — `.claude/workflow/gate-prd-{session}/`에만 출력
- PRD 파일 자체도 자동 수정 안 함 — 개선안만 제시, 적용은 사용자가
- 같은 PRD를 여러 번 검증 가능 (매번 새 세션)
- P0이 0개여야 다음 Gate(/hwan-refactor-code)로 진행 권장
