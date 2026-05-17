---
description: Release Gate - final pre-deploy validation (security, QA, docs, README) using gstack + BMAD
---

# Purpose
**Gate 4: Release Gate.** 배포 직전, PR 만들기 전, README/문서 정리 전. 최종 코드 품질, 보안, QA, 성능, 문서, README, git/PR/배포 준비 검증.

# Arguments
- No arg: deep mode (full parallel pre-release audit)
- `--quick`: 핵심만 (`/cso` + `/qa` + `/ship` preflight)
- `--no-ship`: ship 단계 제외 (검증만, PR 안 만듦)
- `--target <branch>`: 비교 기준 브랜치 (default: main)
- `--audit-only`: stop after audit + plan, do not execute fixes
- `--dry-run`: preview changes without modifying files
- `--include-p2`: include P2 items in execution (default: only P0/P1)
- `--resume`: resume from last incomplete execution

# Recommended Model
**Claude Opus** for this command. The adversarial and edge-case prompts below use structured output schemas and severity rubrics that benefit significantly from Opus's deeper reasoning.

# Prerequisites

**Installation paths** (Windows):
- gstack 글로벌: `~/.claude/skills/gstack` (global install)
- gstack 프로젝트별 (팀 모드): `<project>/.claude/skills/gstack`
- BMAD: `npx bmad-method install` 한 번 실행 (NPM 패키지)

- **gstack** installed
- **BMAD** installed
- 현재 브랜치 NOT main/master (배포 직전이라도 PR로 가야 함)
- 변경사항 모두 커밋됨

# Execution

## Phase 0: Load prior learnings (compound learning)

Before starting, check if this Gate has accumulated learnings from previous sessions:
- Read `.claude/learnings/git/learnings.md` if exists
- Present learnings to Claude as priors:
  - **Known false positives**: Patterns previously flagged but turned out to be intentional → de-prioritize these
  - **Known true positives**: Patterns that always need fixing → prioritize these
  - **Repeated rollback reasons**: Mistakes that caused regressions before → avoid these patterns
  - **Project-specific context**: Special conventions, third-party constraints, etc.

If no learnings file exists, this is a fresh start — that's fine.

These learnings inform downstream phases but **don't override user judgment**. Always show the user what learnings are being applied.


## Phase 1: Pre-release health summary

Pull together diff stats + 변경 영역 매핑:
- `git diff --stat {target}..HEAD`
- 변경된 파일 카테고리 (코드/테스트/문서/설정)
- 마지막 PR/배포 이후 누적 변경량
- 테스트 통과율 baseline

Output: `.claude/workflow/gate-release-{YYYY-MM-DD}-{NNN}/health-summary.md`

`--quick` 모드면 Phase 2의 핵심 3개만 실행하고 Phase 5로.

## Phase 2: Multi-dimensional parallel audit

**Use Task tool to fire ALL of these in ONE response (parallel — 가장 큰 병렬화 효과):**

| Skill | Source | Focus |
|-------|--------|-------|
| `/cso` | gstack | **보안 감사 (OWASP + STRIDE)** — 배포 직전 필수 |
| `/qa` | gstack | **최종 회귀 테스트** — 실제 브라우저 클릭 |
| `/benchmark` | gstack | 성능 baseline (배포 전 기준 확보) |
| `bmad-code-review` | BMAD | 최종 코드 리뷰 (gstack /review와 다른 관점) |
| `bmad-qa-generate-e2e-tests` | BMAD | E2E 테스트 자동 생성 (누락된 시나리오) |
| `bmad-review-adversarial-general` | BMAD | **배포 후 터질 운영/보안/성능/문서 리스크** 공격 |
| `bmad-review-edge-case-hunter` | BMAD | **권한, 장애, 데이터 손상, 운영 예외, 복구** 케이스 |

Each saves to: `.claude/workflow/gate-release-{session}/audit/{skill}.md`

**Adversarial 프롬프트 (Gate 4 - 배포 공격)**:

```
역할: 시니어 SRE + 보안 엔지니어가 이 배포의 운영 리스크를 공격적으로 찾는다.

대상: {current_branch} (배포 대상 코드)
변경 범위: {diff_summary}

다음 9개 카테고리에서 배포 후 터질 리스크 탐색:
1. **인증/권한 약점**: 토큰 검증 부재, 권한 체크 누락, 세션 고정
2. **인증 우회**: SQL injection, XSS, CSRF, path traversal
3. **성능 절벽**: 첫 사용자 100명 OK, 1000명 시 죽음 (N+1, 락 경합, 캐시 없음)
4. **의존성 취약점**: outdated 패키지, 알려진 CVE, 라이선스 문제
5. **롤백 불가**: 데이터 마이그레이션 비가역, schema breaking
6. **모니터링 사각지대**: 에러 추적 없음, 알림 없음, 핵심 메트릭 안 봄
7. **시크릿 노출**: API 키 하드코딩, .env 커밋, 로그에 토큰
8. **운영 가이드 부재**: README에 배포/롤백 절차 없음, 트러블슈팅 없음
9. **외부 의존 SPOF**: 한 외부 API 죽으면 전체 죽음, 재시도/서킷브레이커 없음

각 발견사항 출력 형식 (필수):
- **category**: [위 9개 중]
- **location**: file:line / config / infrastructure
- **vulnerability**: 무엇이 취약한지
- **production_scenario**: 배포 후 어떤 상황에서 터질지 (구체적)
- **blast_radius**: 영향 범위 (사용자 N명? 데이터 손실? 다운타임?)
- **severity**: P0 | P1 | P2 | P3
- **evidence**: 코드/설정 인용
- **mitigation**: 즉시 차단 가능한 조치 + 장기 해결책

심각도 기준 (배포 차단 기준):
- P0: **배포 차단**. 보안 우회/데이터 손실/즉각 장애 가능 (이 1개라도 있으면 ship X)
- P1: 배포 후 24시간 내 문제 발생 가능
- P2: 일주일 내 발견될 운영 이슈
- P3: 모니터링 추가 필요 정도

엄격한 규칙:
- 모든 P0는 **반드시 구체적 exploit 시나리오** 제시 (실제 공격 가능한 케이스)
- "보안 검토 필요" 금지
- 인용 + 위치 정확히
- 추측이면 "추정", 확실하면 명시

응답 마지막 필수:
- ship_recommendation: SHIP | SHIP WITH WATCHLIST | BLOCK
- block_reason (BLOCK 시): 차단 이유 P0 항목 목록
- watchlist_items: 배포 후 모니터링해야 할 항목
- rollback_plan_completeness: 1-10 (롤백 절차가 준비된 정도)
- recommended_runbook_additions: 운영 매뉴얼에 추가할 절차
```

**Edge-case 프롬프트 (Gate 4 - 운영 환경 누락 탐지)**:

```
역할: 시니어 SRE + 운영 엔지니어가 운영 환경에서 발생할 모든 케이스를 점검한다.

대상: 배포 직전 상태의 {current_branch}

다음 6개 카테고리 모두 점검 (체크리스트):
1. **권한 케이스**:
   - admin / staff / user / guest / anonymous 각각 행동
   - 토큰 만료 / 토큰 재발급 중 요청
   - 권한 변경 직후 (구 권한으로 캐시된 토큰)
   - 본인/타인 데이터 접근 경계
2. **장애 케이스**:
   - DB 연결 실패 / 슬로우 쿼리 / 트랜잭션 데드락
   - 외부 API 5xx / 타임아웃 / rate limit
   - 부분 실패 (3개 호출 중 1개 실패)
   - 캐시 죽음 (캐시 의존 시 thundering herd)
3. **데이터 케이스**:
   - 마이그레이션 미실행 상태로 배포
   - 손상된 데이터 (NULL이어야 할 곳에 빈 문자열)
   - 동시 수정 충돌 (낙관적 락 없음)
   - 대용량 데이터 (백만 행 query, 거대한 페이로드)
4. **운영 케이스**:
   - 배포 중 in-flight 요청 처리
   - 캐시 stampede (배포 직후 모두가 캐시 미스)
   - 트래픽 스파이크 (10x 갑작스러운 증가)
   - 백그라운드 작업과 배포 충돌
5. **복구 케이스**:
   - 롤백 절차 명문화됨? 테스트됨?
   - 핫픽스 빠른 배포 가능?
   - 데이터 복원 절차 (백업 → 복원 검증)
   - 부분 롤백 (특정 feature flag만)
6. **모니터링/관측성**:
   - 모든 핵심 플로우에 로깅?
   - 에러는 알림 시스템에 연결?
   - 핵심 메트릭 대시보드?
   - 분산 트레이싱 (마이크로서비스 시)

각 발견사항 출력 형식 (필수):
- **category**: [위 6개 중]
- **location**: 해당 영역 (코드/설정/인프라/문서)
- **missing_handling**: 어떤 운영 케이스가 처리 안 됨
- **production_trigger**: 이 케이스를 발생시키는 실제 운영 조건
- **what_happens_now**: 현재 어떻게 동작하나 (조용히 실패? 사용자에게 보임?)
- **severity**: P0 | P1 | P2 | P3
- **fix_required**: 코드 변경? 설정? 문서? 모니터링?
- **suggested_implementation**: 구체적 구현 방향

심각도 기준:
- P0: 배포 후 1-7일 내 100% 발생할 운영 이슈 (예: 권한 체크 누락)
- P1: 한 달 내 발견될 (예: 캐시 stampede 대응 없음)
- P2: 트래픽 증가 시 발견될 (예: 성능 최적화)
- P3: 베스트 프랙티스 수준

엄격한 규칙:
- 반드시 production_trigger 구체적으로 ("동시 사용자 1000명" 같은 조건)
- "운영 안정성 검토 필요" 같은 모호한 발견 금지
- 카테고리별 최소 2개 점검

응답 마지막 필수:
- operational_readiness_score: 1-10 (운영 준비도)
- critical_runbooks_missing: 작성 필요한 runbook 목록
- monitoring_gaps: 추가 필요한 모니터링 항목
- chaos_test_candidates: 카오스 엔지니어링으로 검증할 시나리오 3개
```

## Phase 3: Documentation update

### 3a. `/document-release` (gstack)
README, ARCHITECTURE, CONTRIBUTING, CLAUDE.md 등 변경 사항 반영해서 자동 업데이트.
- 변경된 모든 doc 파일 식별
- diff 기반 업데이트 생성
- 사용자 확인 후 적용

**Note**: 첨부 문서의 `/document-generate`는 gstack에 없어요. `/document-release`로 통일.

Output: `.claude/workflow/gate-release-{session}/docs-update.md` (변경 제안)

## Phase 4: Ship preflight (조건부)

`--no-ship` 이면 Phase 5로.

### 4a. `/ship` preflight (gstack)
- main 동기화 체크
- 테스트 실행
- 커버리지 감사
- **PR 생성 직전까지만** — 실제 PR 생성은 사용자 확인 후

Output: `.claude/workflow/gate-release-{session}/ship-preflight.md`

**Halt conditions (배포 차단)**:
- 보안 이슈 P0가 있음 (`/cso`에서 critical 발견)
- 테스트가 baseline보다 안 통과
- 변경된 코드의 critical path에 테스트 0개

## Phase 5: Synthesis with deploy-readiness verdict

Create `.claude/workflow/gate-release-{session}/SUMMARY.md`:

```markdown
# Release Gate 검증 결과

## 배포 판정
{🟢 SHIP / 🟡 SHIP WITH WATCHLIST / 🔴 BLOCK — 배포 불가}

## 차단 항목 (있을 경우)
### 🔴 반드시 배포 전 해결
1. [출처: cso] {보안 이슈} → {필수 조치}
2. [출처: qa] {회귀 발견} → {수정 필요}

## 통합 이슈 (P0/P1/P2/P3)

### P0 (배포 차단)
...

### P1 (배포 가능하나 추적 필요)
...

### P2 (배포 후 처리)
...

### P3 (참고)
...

## 영역별 결과

### 🔒 보안 (/cso)
- 발견된 취약점: {N}개 (severity 분포)
- OWASP Top 10 매핑: ...
- STRIDE 위협 모델: ...

### 🧪 테스트 (/qa + bmad-qa-generate-e2e-tests)
- 회귀 테스트 결과: ...
- 자동 생성된 E2E 시나리오: {N}개
- 추가 권장 테스트: {N}개

### ⚡ 성능 (/benchmark)
- 페이지 로드: {N}ms
- 회귀: {없음 / 있음 — 상세}

### 📝 문서 (/document-release)
- README 업데이트: {N}곳
- 기타 문서: {파일 목록}

### ⚔️ Adversarial
- 배포 후 터질 리스크: {top 3}

### 🎯 Edge cases
- 운영 환경 케이스: {top 3 누락}

## README/문서 보강 항목
구체적인 추가/수정 텍스트 (복붙 가능)

## 추가 테스트 후보
- {시나리오 1}: 우선순위 P0
- {시나리오 2}: 우선순위 P1

## 최종 ship 가능 여부
{🟢 Ship 가능 / 🟡 조건부 / 🔴 Block}

이유: ...
```


## Phase 6: Execute release-blocking fixes

`--audit-only` flag가 있으면 이 phase는 skip.

### 6a. Pre-execution
- 현재 브랜치 NOT main/master
- 모든 변경 commit됨
- 테스트 baseline 저장
- 보안 스캔 baseline 저장 (`/cso` 재실행 가능 상태)

### 6b. Parse plan items by category
SUMMARY.md에서 카테고리별로 추출:
- 🔒 **보안 (critical first)**: 인증, 권한, 의존성 CVE
- 🧪 **테스트**: 누락된 E2E, 단위 테스트
- 📝 **문서**: README, runbook, 배포 가이드
- ⚡ **성능**: 최적화 항목
- 🔧 **운영**: 모니터링, 알림 설정

### 6c. Execute by category (security first, always)

**Priority order (배포 차단 항목 우선)**:
1. **보안 P0** (모두 순차 실행, 가장 신중):
   - 각 보안 fix: snapshot → apply → /cso 재검증 → commit or rollback
   - **Critical 1개라도 fix 실패 시 STOP** (배포 불가)

2. **테스트 P0/P1** (병렬 가능):
   - `bmad-qa-generate-e2e-tests`로 누락 시나리오 생성
   - 새 테스트 추가, 실행, 통과 확인
   - 통과 못하면 그 테스트만 rollback

3. **문서 업데이트** (병렬):
   - `/document-release`로 README, ARCHITECTURE, CLAUDE.md 등 자동 업데이트
   - 사용자 검토용 diff 생성
   - 명시적 사용자 승인 후 commit

4. **성능 P0/P1** (병렬, 신중):
   - 각 최적화: 적용 → `/benchmark` 비교
   - 회귀 시 rollback

5. **운영 설정** (병렬):
   - 모니터링 코드, 알림 설정 추가
   - 검증 가능한 경우만 자동 (불가하면 사용자에게 안내)

### 6d. Post-fix re-audit
모든 수정 완료 후:
- `/cso` 재실행 → critical 0개여야 ship 가능
- 전체 테스트 한 번 더
- `/benchmark` 재실행 → 성능 회귀 없음 확인

### 6e. Ship preparation
모든 검증 통과 시:
- `/ship` preflight 자동 실행
- PR 본문 생성 (변경 요약, 해결한 이슈, 검증 결과)
- **PR 생성은 사용자 명시 승인 후만**

### 6f. Dry-run mode
`--dry-run`이면 각 카테고리별 변경 미리보기 + ship 시뮬레이션.

### Halt conditions (배포 직전이라 가장 엄격)
- 보안 critical 1개라도 fix 실패 → STOP, ship 불가
- 테스트 통과율 떨어짐 → STOP
- 의존성 취약점 새로 도입 → STOP
- 30+ 파일 수정 시도 → STOP (계획 오해)
- main/master 수정 시도 → STOP


## Phase 7: Capture compound learnings

After execution completes (or even if --audit-only), capture what was learned this session.

### 7a. Analyze session outcomes
From state.json and execution logs, identify:
- **Successfully applied fixes**: Item → reason it worked
- **Rolled back items**: Item → why it failed (regression? wrong fix? user disagreed?)
- **Skipped by user**: Item → why user said no
- **Recurring patterns**: Same type of issue flagged multiple times (signal of false positive or project-specific norm)

### 7b. Extract learnings (structured)
Generate new entries for `.claude/learnings/git/learnings.md` in this format:

- Learning title (short)
- Date / source session
- Category: false_positive | true_positive | rollback_pattern | project_context
- Pattern: what to look for
- Action: what to do when seeing this pattern
- Evidence: file/PR/commit demonstrating this
- Confidence: 1-10

### 7c. Append to persistent store
- Path: `.claude/learnings/git/learnings.md`
- Append (don't overwrite) — preserve history
- Also append to `.claude/learnings/index.md` (global overview)

### 7d. Optional: Register with gstack /learn
If gstack `/learn` is available, register globally for cross-gate visibility.

### 7e. Report what was learned
Tell the user explicitly what learnings were added this session and where they're stored.


# Final Report (Korean)

```
{🟢/🟡/🔴} Release Gate 검증 완료

세션: gate-release-{date}-{nnn}
실행 시간: {elapsed}
변경 범위: +{insertions} -{deletions} ({files}개 파일)

📋 배포 판정: {SHIP / WITH WATCHLIST / BLOCK}

📊 이슈 통계:
   P0 (배포 차단): {N}개
   P1 (배포 후 추적): {N}개
   P2 (배포 후 처리): {N}개
   P3 (참고): {N}개

🔒 보안 (/cso):
   - Critical: {N}개  ← 0이어야 ship 가능
   - High: {N}개
   - Medium: {N}개

🧪 테스트:
   - 통과: {pass}/{total}
   - 회귀: {N}건
   - E2E 자동 생성: {N}개 시나리오

⚡ 성능:
   - 로드 시간 회귀: {없음 / +{N}ms}

📝 문서:
   - 업데이트 필요: {N}곳
   - README 보강: {N}개 섹션

🚀 다음 단계:

{SHIP 시}
   1. /document-release 변경 적용 (검토 후 commit)
   2. /ship으로 PR 생성 (또는 본인이 직접 gh pr create)
   3. CI 통과 후 직접 머지
   4. 배포 후 모니터링 (gstack /canary 활용 가능)

{WITH WATCHLIST 시}
   - 배포 가능. P1 이슈를 별도 이슈로 등록 후 추적
   - {watchlist 핵심 항목}

{BLOCK 시}
   - 차단 항목 처리 후 재실행
   - P0 이슈 해결 → /hwan-refactor-code → 본 Gate 재실행


────────────────────────────────────────
실행 결과 (Execute Phase)
────────────────────────────────────────
{✅ 완료 / ⚠️ 부분 / 🛑 중단 / ⬜ 스킵 (audit-only)}

🔒 보안 수정:
   - Critical: ✅ {c_done}/{c_total} (0 남아야 ship 가능)
   - High: ✅ {h_done}/{h_total}

🧪 테스트 추가:
   - 새 E2E 시나리오: {N}개 추가
   - 기존 테스트 통과: {pass}/{total}

📝 문서 업데이트:
   - README: ✅ 적용
   - ARCHITECTURE: ✅ 적용
   - runbook: {N}개 추가

⚡ 성능 최적화:
   - 적용: {N}건
   - 성능 변화: {before}ms → {after}ms

📦 Ship 상태:
   - /cso 재검증: ✅ critical 0개
   - 테스트: ✅ {pass_rate}%
   - 성능: ✅ 회귀 없음
   - 최종 판정: {SHIP / BLOCK}

📋 PR 준비:
   - 본문 생성됨: .claude/workflow/gate-release-{session}/pr-body.md
   - 직접 실행: `gh pr create` 또는 GitHub UI

ℹ️ PR/머지/배포는 절대 자동 X. 본인 명시 승인 필요.

────────────────────────────────────────
🧠 Compound 학습 (이번 세션)
────────────────────────────────────────
새로 추가된 학습: {N}개
  - {learning_1}
  - {learning_2}
  - {learning_3}

전체 누적 학습: {total_N}개
저장 위치: .claude/learnings/git/learnings.md

다음 실행 시 자동 적용됩니다.

📁 상세: .claude/workflow/gate-release-{session}/
   - SUMMARY.md ← 먼저 보세요 (배포 판정 + 차단 항목)
   - audit/ ← 영역별 결과
   - docs-update.md ← 문서 변경 제안

ℹ️ PR/머지/배포는 모두 사용자가 직접. 이 명령은 검증과 PR 생성까지만.
```

# Mode Reference

| Mode | 실행 내용 | 예상 시간 |
|------|----------|----------|
| `--quick` | /cso + /qa + ship preflight | 8-15분 |
| (기본/deep) | 7개 병렬 audit + 문서 + ship preflight | 20-40분 |
| `--no-ship` | 위 검증만, PR 생성 안 함 | -3분 |

# 범용 기능 재사용 규칙 (이 Gate에서)
- `bmad-review-adversarial-general` → **운영/보안/성능/문서** 관점 공격 (배포 리스크)
- `bmad-review-edge-case-hunter` → **권한/장애/데이터/복구** 운영 케이스
- `/qa` → **최종 회귀 테스트**
- `/benchmark` → **배포 전 성능 기준**
- `/document-release` → **README/문서 고도화**

# Notes
- **PR 생성 / 머지 / 배포는 절대 자동 아님** — `/ship`도 PR 생성 직전까지만, 실제 PR 생성은 본인이
- Critical 보안 이슈 있으면 무조건 BLOCK (override 불가)
- 같은 브랜치 여러 번 검증 가능 (수정 후 재실행)
- 배포 후에는 `/canary` (gstack)로 모니터링 별도 권장
