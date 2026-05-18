# Codex Prompt


# Purpose
**Gate 3: Refactor-Design Gate.** UI 구현 후 디자인 리팩토링 중. 단순히 화면 깨졌는지 확인이 아니라, **UI/UX 개선점을 최대한 많이 발굴**.

# Arguments
- No arg: deep mode (parallel full UI/UX audit)
- `--quick`: `/qa` + `/design-review` only
- `--url <url>`: specify URL to test (default: detect from package.json/config)
- `--screen <path>`: focus on specific screen/component file
- `--audit-only`: stop after audit + plan, do not execute fixes
- `--dry-run`: preview changes without modifying files
- `--include-p2`: include P2 items in execution (default: only P0/P1)
- `--resume`: resume from last incomplete execution

# Prerequisites

**Installation paths** (Windows):
- gstack 글로벌: `~/.claude/skills/gstack` (global install)
- gstack 프로젝트별 (팀 모드): `<project>/.claude/skills/gstack`
- BMAD: `npx bmad-method install` 한 번 실행 (NPM 패키지)

- **gstack** installed (`/qa`, `/design-review`, `/benchmark` 필요)
- **BMAD** installed
- UI 구현 코드 존재 (웹앱/모바일/대시보드 등)
- 가능하면 staging 또는 localhost dev 서버 실행 중

# Execution

## Phase 0: Load prior learnings (compound learning)

Before starting, check if this Gate has accumulated learnings from previous sessions:
- Read `.claude/learnings/design/learnings.md` if exists
- Present learnings to Claude as priors:
  - **Known false positives**: Patterns previously flagged but turned out to be intentional → de-prioritize these
  - **Known true positives**: Patterns that always need fixing → prioritize these
  - **Repeated rollback reasons**: Mistakes that caused regressions before → avoid these patterns
  - **Project-specific context**: Special conventions, third-party constraints, etc.

If no learnings file exists, this is a fresh start — that's fine.

These learnings inform downstream phases but **don't override user judgment**. Always show the user what learnings are being applied.


## Phase 1: QA functional baseline

### 1a. `/qa` (gstack) — 기능 동작 확인
브라우저로 실제 클릭, 화면 캡처. 기능적 버그 먼저 식별.
**자동 수정 기능은 비활성** (이 Gate는 보고만, 수정은 사용자가 결정).

Output: `.claude/workflow/gate-design-{YYYY-MM-DD}-{NNN}/qa-baseline.md`

`--quick` 모드면 Phase 2의 `/design-review`만 추가 실행하고 Phase 5로.

## Phase 2: Multi-perspective UI/UX parallel review

**Run all in parallel:**

| Skill | Source | Focus |
|-------|--------|-------|
| `/design-review` | gstack | 디자인 감사 (사용자 흐름, 일관성, polish) |
| `bmad-review-adversarial-general` | BMAD | **UI/UX가 왜 사용자 이탈을 만들 수 있는지** 공격적 비판 |
| `bmad-review-edge-case-hunter` | BMAD | **empty/loading/error/success/disabled/mobile/long-text** 상태 누락 |

**Adversarial 프롬프트 (Gate 3 - UX 공격)**:

```
역할: 시니어 UX 디자이너 + 그로스 마케터가 이 UI를 공격적으로 비판한다.

대상: {screen_or_url}
스크린샷: {screenshot_paths}

다음 8개 카테고리에서 이탈/전환율 저하 요소 탐색:
1. **첫 화면 혼란**: 사용자가 "여기서 뭘 해야 하지?" 5초 안에 답 못함
2. **핵심 CTA 묻힘**: 주요 행동 버튼이 secondary action에 묻히거나 안 보임
3. **불필요한 단계**: 3단계로 가능한 걸 7단계로 만듦
4. **신뢰 신호 부재**: 보안 표시, 사회적 증거, 환불 정책 등이 결제 직전에 없음
5. **모바일 어색함**: 터치 영역 작음, 가로 스크롤, 키보드 가림
6. **접근성 문제**: 색 대비 부족, 키보드 네비게이션 안 됨, alt 텍스트 없음
7. **AI Slop 디자인**: 기본 템플릿 같음, 차별성 없음, 영혼 없음
8. **신뢰감 저하**: 깨진 정렬, 일관성 없는 폰트, 어색한 copy

각 발견사항 출력 형식 (필수):
- **category**: [위 8개 중]
- **location**: screen / component name (예: "/checkout, 결제 버튼")
- **problem**: 1-2문장
- **user_drop_off_scenario**: 사용자가 정확히 어디서 이탈하는지
- **estimated_impact**: 영향 추정 (예: "전환율 -10~20%", "지원 문의 증가")
- **severity**: P0 | P1 | P2 | P3
- **evidence**: 스크린샷 영역 설명 또는 컴포넌트 인용
- **fix_with_copy**: 구체적 수정안 (UI copy/레이아웃 변경 포함)

심각도 기준:
- P0: 핵심 전환 플로우 막힘 (회원가입/결제 실패)
- P1: 명백한 이탈 유발 요소, 측정 가능한 임팩트
- P2: 사용성 저하 (불만은 있으나 이탈은 X)
- P3: polish 수준

엄격한 규칙:
- "사용자 경험을 개선하세요" 같은 모호한 비판 금지
- 반드시 구체적 위치 (어느 화면, 어느 컴포넌트)
- 카테고리당 최대 3개
- UI copy 수정안은 한국어로 그대로 제시 (복붙 가능)

응답 마지막 필수:
- conversion_risk_score: 1-10 (현재 디자인이 전환을 얼마나 해치는지)
- top_5_must_fix: 반드시 고쳐야 할 5개 (P0/P1 위주)
- a_b_test_candidates: A/B 테스트로 검증할 만한 가설 3개
- competitor_comparison: 동종 업계 베스트와 비교 시 약점
```

**Edge-case 프롬프트 (Gate 3 - 상태별 화면 누락 탐지)**:

```
역할: QA + UI/UX 디자이너가 모든 화면의 누락된 상태를 찾는다.

대상: {all_screens_or_components}

각 화면에 대해 다음 10개 상태 체크리스트 점검:
1. **empty**: 데이터 0개일 때 (첫 사용, 검색 결과 없음, 필터로 모두 제외)
2. **loading**: 데이터 fetching 중 (스켈레톤, 스피너, progress)
3. **error**: 에러 발생 (네트워크, 권한, 서버 5xx, 유효성)
4. **success**: 작업 성공 피드백 (저장됨, 전송됨, 등록됨)
5. **disabled**: 액션 불가 상태 (조건 미충족, 권한 없음, 로딩 중)
6. **mobile_responsive**: 모바일/태블릿에서 어색함
7. **long_text**: 긴 이름/제목/주소가 레이아웃 깨뜨림
8. **special_chars**: 이모지, RTL 언어, 한자/일본어
9. **permission**: 권한 없는 사용자가 봤을 때 (숨김? 비활성? 에러?)
10. **offline**: 네트워크 끊긴 상태 (오프라인 안내, 큐잉)

각 발견사항 출력 형식 (필수, 화면별 매트릭스):

| 화면 | empty | loading | error | success | disabled | mobile | long_text | special | permission | offline |
|------|-------|---------|-------|---------|----------|--------|-----------|---------|------------|---------|
| 홈 | ❌ | ✅ | ❌ | ✅ | - | ⚠️ | ❌ | ❌ | ✅ | ❌ |
| 검색 | ✅ | ✅ | ✅ | - | ✅ | ✅ | ⚠️ | ❌ | ✅ | ❌ |
...

(✅ 구현됨, ❌ 누락, ⚠️ 부분/문제 있음, - 해당 없음)

각 ❌/⚠️ 항목에 대해 상세:
- **screen**: 화면명
- **state**: 어떤 상태가 누락
- **what_user_sees_now**: 현재 사용자가 보는 것 (백지? 무한 로딩? crash?)
- **what_should_happen**: 어떻게 동작해야 하나
- **severity**: P0 | P1 | P2 | P3
- **design_suggestion**: 구체적 디자인 제안 (UI copy + 레이아웃 + 아이콘)

심각도 기준:
- P0: 사용자가 막히거나 데이터 손실 가능 (예: 결제 중 에러 화면 없음)
- P1: 주요 화면의 핵심 상태 누락 (예: 빈 목록 화면)
- P2: 부차적 화면의 상태 누락
- P3: polish 수준

엄격한 규칙:
- 반드시 매트릭스 + 상세 둘 다 제공
- "에러 처리 필요" 금지, 구체적 화면/상태/디자인만
- 모든 주요 화면 커버 (홈, 핵심 플로우, 설정 등)

응답 마지막 필수:
- completeness_score: 1-10 (전체 상태 커버리지)
- worst_screen: 상태 누락 가장 많은 화면 + 이유
- quick_wins: 빠르게 추가 가능한 상태 5개 (저비용 고효과)
- design_system_gaps: 디자인 시스템에 추가해야 할 컴포넌트
```

## Phase 3: UX design improvement (creative)

### 3a. `bmad-create-ux-design`
지금까지 발견된 문제 기반으로 **개선 디자인 제안**. 단순 지적이 아닌 구체적 변경안.
Output: `.claude/workflow/gate-design-{session}/ux-improvement.md`

## Phase 4: Performance baseline

### 4a. `/benchmark` (gstack)
페이지 로드, Core Web Vitals, 리소스 크기 측정.
Output: `.claude/workflow/gate-design-{session}/benchmark.md`

## Phase 5: Mandatory checklist (이 Gate에서 반드시 보는 항목)

리뷰들의 결과를 다음 체크리스트로 매핑:

- [ ] 사용자가 첫 화면에서 무엇을 해야 하는지 명확한가
- [ ] 핵심 CTA가 잘 보이는가
- [ ] 불필요한 단계가 있는가
- [ ] 레이아웃, spacing, typography, 색상, 버튼, 카드, 폼 스타일 일관성
- [ ] 모바일/반응형 어색함
- [ ] empty/loading/error/success/disabled 상태 준비
- [ ] 접근성 문제 (대비, 키보드, 스크린리더)
- [ ] 디자인이 기본 템플릿처럼 보이는가 (AI Slop)

## Phase 6: Synthesis with P0/P1/P2/P3 + 특수 산출물 형식

Create `.claude/workflow/gate-design-{session}/SUMMARY.md`:

```markdown
# Refactor-Design Gate 검증 결과

## 판정
{🟢 SHIP-READY / 🟡 POLISH NEEDED / 🔴 MAJOR UX ISSUES}

## 반드시 고쳐야 할 것 TOP 5
각 항목마다:
1. **현재 문제**: ...
2. **사용자 영향**: ...
3. **추천 수정안**: ...
4. **바로 적용 가능한 UI copy / 레이아웃**: ...

## 빠르게 개선 가능한 것 TOP 5
(저비용 고효과)

## 디자인 완성도 polish TOP 5
(시간 있을 때)

## 상태별 화면 누락 목록
| 화면 | empty | loading | error | success | disabled | mobile |
|------|-------|---------|-------|---------|----------|--------|
| 홈   | ❌    | ✅      | ❌    | ✅      | -        | ⚠️     |
...

## 우선순위 정리 (P0/P1/P2/P3)

### P0 (배포 전 필수)
- {화면}: {문제} → {수정안}

### P1 (강력 권장)
...

### P2 (개선)
...

### P3 (polish)
...

## 다음 디자인 리팩토링 작업 단위
(논리적 그룹으로 묶음 — 한 번에 끝낼 수 있는 단위)
1. **첫 화면 명확성**: P0.1, P0.2, P1.3
2. **상태 완성**: P0.5, P1.1, P1.2
3. **반응형 정리**: P1.4, P2.1, P2.2
```


## Phase 7: Execute UI/UX fixes

`--audit-only` flag가 있으면 이 phase는 skip.

### 7a. Pre-execution
- 현재 브랜치 NOT main/master
- UI 빌드/렌더링 가능 상태 확인
- 가능하면 dev 서버 실행 중 (시각 검증용)
- 스크린샷 baseline 저장: `.claude/workflow/gate-design-{session}/screenshots/before/`

### 7b. Parse plan items
SUMMARY.md의 P0/P1 항목 (--include-p2면 P2까지). 각 항목:
- screen / component
- 변경 사항 (CSS, 레이아웃, copy 등)
- 검증 기준 (visual diff, 사용성 체크)

### 7c. Group execution (디자인은 화면별 그룹화)
같은 화면/컴포넌트 수정은 순차 실행 (충돌 방지).
다른 화면 수정은 병렬 가능.

For each group:

**Parallel via Task tool**, each Task:
1. **Snapshot**: `git stash push -u -m "pre-{item-id}"` + screenshot 저장
2. **Apply fix**:
   - CSS 수정, 컴포넌트 코드 수정, copy 변경 등
   - 디자인 시스템 일관성 유지
3. **Visual verification**:
   - 영향받은 화면 렌더링
   - before/after 스크린샷 비교
   - 의도한 변경이 보이는지 확인
4. **Regression check**:
   - 다른 화면이 깨지지 않았는지 (기존 테스트 + 렌더링)
5. **Decision**:
   - ✅ 의도한 변경 + 다른 화면 영향 없음 → COMMIT: `refactor(ui): {item_id} {title}`
   - ❌ 시각 회귀 또는 의도와 다름 → ROLLBACK
6. **Log + screenshot**: `.claude/workflow/gate-design-{session}/fixes/{item-id}.md` + 스크린샷

### 7d. Mandatory checklist re-verification
Phase 5의 체크리스트(empty/loading/error/success/disabled/mobile)를 다시 점검.
수정 후에도 매트릭스 업데이트.

### 7e. Final benchmark
`/benchmark` 다시 실행해서 성능 회귀 없는지 확인.

### 7f. Dry-run mode
`--dry-run`이면 변경 사항 + 예상 영향 미리보기, 실제 수정 X.

### Halt conditions
- 빌드 실패
- 한 그룹 50%+ 실패
- 의도한 화면 외 영향 감지 (다른 화면 깨짐)
- 성능 20%+ 회귀


## Phase 8: Capture compound learnings

After execution completes (or even if --audit-only), capture what was learned this session.

### 8a. Analyze session outcomes
From state.json and execution logs, identify:
- **Successfully applied fixes**: Item → reason it worked
- **Rolled back items**: Item → why it failed (regression? wrong fix? user disagreed?)
- **Skipped by user**: Item → why user said no
- **Recurring patterns**: Same type of issue flagged multiple times (signal of false positive or project-specific norm)

### 8b. Extract learnings (structured)
Generate new entries for `.claude/learnings/design/learnings.md` in this format:

- Learning title (short)
- Date / source session
- Category: false_positive | true_positive | rollback_pattern | project_context
- Pattern: what to look for
- Action: what to do when seeing this pattern
- Evidence: file/PR/commit demonstrating this
- Confidence: 1-10

### 8c. Append to persistent store
- Path: `.claude/learnings/design/learnings.md`
- Append (don't overwrite) — preserve history
- Also append to `.claude/learnings/index.md` (global overview)

### 8d. Optional: Register with gstack /learn
If gstack `/learn` is available, register globally for cross-gate visibility.

### 8e. Report what was learned
Tell the user explicitly what learnings were added this session and where they're stored.


# Final Report (Korean)

```
{🟢/🟡/🔴} Refactor-Design Gate 검증 완료

세션: gate-design-{date}-{nnn}
실행 시간: {elapsed}

📋 판정: {SHIP-READY / POLISH NEEDED / MAJOR UX ISSUES}

📊 이슈 통계:
   P0 (배포 전 필수): {N}개
   P1 (강력 권장): {N}개
   P2 (개선): {N}개
   P3 (polish): {N}개

🎯 TOP 5 카테고리:
   반드시 고쳐야 할 것: {N}개
   빠른 개선 (저비용 고효과): {N}개
   디자인 polish: {N}개

📱 상태별 화면 누락:
   - empty: {N}개 화면
   - loading: {N}개
   - error: {N}개
   - mobile 깨짐: {N}개

⚔️ Adversarial 발견:
   - 이탈 유발 요소: {top 1}
   - 신뢰감 저하: {top 1}

⚡ 성능 (benchmark):
   - 페이지 로드: {N}ms
   - LCP/FID/CLS: {수치}

🚀 다음 단계:
   {SHIP-READY 시} → /hwan-refactor-git (배포 전 최종 검증)
   {POLISH NEEDED 시} → "다음 작업 단위" 순서대로 처리
   {MAJOR UX 시} → P0 처리 후 재실행


────────────────────────────────────────
실행 결과 (Execute Phase)
────────────────────────────────────────
{✅ 완료 / ⚠️ 부분 / 🛑 중단 / ⬜ 스킵 (audit-only)}

🎨 UI/UX 수정 적용:
   P0: ✅ {p0_done}/{p0_total}
   P1: ✅ {p1_done}/{p1_total}
   P2: ⚠️ {p2_done}/{p2_total}

📸 스크린샷 비교:
   - before/after 저장: .claude/workflow/gate-design-{session}/screenshots/
   - 의도한 변경: {N}건 확인됨
   - 예상 외 변경: {N}건 (rollback됨)

📝 커밋: {N}개  (atomic, 화면별 분리)

🧪 회귀:
   - 기존 테스트: {pass}/{total}
   - 시각 회귀: {N}건 (자동 롤백됨)
   - 성능 회귀: {N}ms (이전 대비)

📋 체크리스트 재검증:
   - empty state 누락: {before} → {after}
   - loading: {before} → {after}
   - error: {before} → {after}
   ...

❌ 실패 항목:
   - {item_id} {title} - {reason}

────────────────────────────────────────
🧠 Compound 학습 (이번 세션)
────────────────────────────────────────
새로 추가된 학습: {N}개
  - {learning_1}
  - {learning_2}
  - {learning_3}

전체 누적 학습: {total_N}개
저장 위치: .claude/learnings/design/learnings.md

다음 실행 시 자동 적용됩니다.

📁 상세: .claude/workflow/gate-design-{session}/
   - SUMMARY.md ← 작업 단위 + TOP 5 + 누락 매트릭스
   - ux-improvement.md ← 구체적 디자인 제안
   - benchmark.md ← 성능 지표
```

# Mode Reference

| Mode | 실행 내용 | 예상 시간 |
|------|----------|----------|
| `--quick` | /qa + /design-review | 5-10분 |
| (기본/deep) | 위 + 병렬 리뷰 + ux-improvement + benchmark | 15-30분 |

# 범용 기능 재사용 규칙 (이 Gate에서)
- `bmad-review-adversarial-general` → **UX/이탈/신뢰감** 관점 공격
- `bmad-review-edge-case-hunter` → **상태별 화면** 누락 탐지 (이 Gate의 핵심)
- `/qa` → **UX 플로우 검증 핵심**
- `/benchmark` → **렌더링/페이지 성능**

# Notes
- **자동 수정 안 함** — `/qa`도 보고 모드로 사용 (수정은 사용자 결정)
- UI 코드 있는 프로젝트에서만 유용 (백엔드/CLI는 `/hwan-refactor-code`만으로 충분)
- staging URL 있으면 더 정확 (실제 환경 테스트)
- 같은 화면 여러 번 검토 가능 (디자인 반복)
