# Claude-Codex Vibekit (한국어)

> Claude Code(선택적으로 Codex CLI) 워크플로우에 얹는 가벼운 로컬 안전 레이어. PRD → 코드 → 디자인 → 릴리스 각 단계에서 체크. **v0.1.0 — 초기 릴리스.**

**English README**: [README.md](README.md)

## 이게 뭐야?

Vibekit은 **또 하나의 AI 코딩 에이전트가 아닙니다.** 기능을 대신 짜주지 않고, 푸시·머지·배포도 하지 않습니다.

대신 기존 Claude Code(또는 Codex CLI) 세션 위에 얹는 **로컬 품질 게이트 워크플로우**입니다:

1. **PRD 게이트** (`/hwan-refactor-idea`) — 코드 쓰기 전에 스펙 점검
2. **코드 게이트** (`/hwan-refactor-code`) — 개발 중간 코드 리뷰, 가능하면 TDD 우선
3. **디자인 게이트** (`/hwan-refactor-design`) — 상태 커버리지 매트릭스로 UI/UX 점검
4. **릴리스 게이트** (`/hwan-refactor-git`) — 배포 전 보안 / QA / 문서 점검

여기에 선택적인 git 안전 훅, 롤백 규칙, 프로젝트별 학습 노트가 더해져서 **반복되는 실수를 잡기 더 쉬워지는 정도**를 노립니다.

## 누구를 위한 거야?

- 바이브 코딩에 구조화된 리뷰 레이어가 필요한 Claude Code 파워 유저
- gstack / BMAD / superpowers / compound-engineering을 이미 쓰거나 설치할 의향이 있는 개발자
- 호스팅 리뷰 플랫폼에 돈 안 쓰고 로컬에서 품질 게이트를 굴리고 싶은 솔로/소규모 팀
- (선택) Codex CLI에서 두 번째 모델로 같은 게이트를 돌리고 싶은 사용자

## 누구한테는 안 맞아?

- 기능을 끝까지 알아서 짜주는 AI를 원하면 — Cursor / Aider / Cline / Continue를 추천합니다.
- 호스팅 대시보드, SSO, 감사 로그, 컴플라이언스 인증이 필요한 팀.
- 로컬 설정을 전혀 하기 싫은 사람. Vibekit은 `~/.claude` 아래에 슬래시 커맨드와 (선택적으로) 훅을 설치합니다.

## Cursor / Aider / Cline / Continue 와 뭐가 달라?

같은 일을 하는 도구가 아니라 **다른 레이어**입니다. 보완 관계지 경쟁 관계가 아닙니다.

| 도구 | 주된 역할 |
|------|----------|
| **Cursor**, **Aider**, **Cline** | 에디터나 터미널에서 AI가 코드를 쓰게 도와줌 |
| **Continue** | 개발/PR 워크플로우 안에서 AI 체크를 굴려줌 |
| **Vibekit** | Claude Code 워크플로우 주변의 로컬 품질 게이트 — PRD 게이트, 코드 게이트, 디자인 게이트, 릴리스 게이트, git 안전 훅, 롤백 규칙, 학습 노트 |

같이 써도 됩니다. AI가 코드 쓰는 건 다른 도구에 맡기고, Vibekit은 "이거 정말 배포해도 되나?" 에 답하는 쪽을 맡습니다.

## 왜?

바이브 코딩은 빠르지만 위험합니다:
- AI가 기존 기능을 깨먹는 걸 못 알아챌 수 있어요.
- 같은 종류의 리뷰 누락이 세션마다 반복돼요.
- 구조화된 리뷰가 없으면 프로덕션에서 사고가 더 자주 납니다.

Vibekit은 가벼운 안전 레이어를 더할 뿐, 휴먼 리뷰를 대체하지 않습니다. 기반:
- **gstack** — 리뷰 스킬 모음 (Garry Tan)
- **BMAD** — 구조화된 워크플로우 (PRD, 시장조사 등)
- **superpowers** — TDD, 체계적 디버깅 (obra)
- **compound-engineering** — 학습 누적 (EveryInc)

## 사전 준비

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Node.js 20+
- Git, Python 3
- (선택) [Codex CLI](https://github.com/openai/codex)

## 설치

Vibekit은 로컬 Claude Code 커맨드를 설치하고, 선택적 통합들을 점검만 합니다. 푸시·머지·배포는 절대 자동으로 하지 않고, auto-commit도 몰래 켜지 않습니다.

### 권장 설치

**macOS / Linux / WSL:**
```bash
git clone https://github.com/YOUR-USERNAME/claude-codex-vibekit.git
cd claude-codex-vibekit
./install.sh --mode safe
./doctor.sh
```

**Windows PowerShell:**
```powershell
git clone https://github.com/YOUR-USERNAME/claude-codex-vibekit.git
cd claude-codex-vibekit
.\install.ps1 -Mode safe
.\doctor.ps1
```

설치 스크립트는:
- OS와 홈 디렉터리를 감지하고
- `/hwan-refactor-*` 슬래시 커맨드를 `~/.claude/commands`에 설치하고
- 훅을 `~/.claude/hooks`에 복사하고
- Claude Code 설정을 백업한 뒤 안전하게 머지하고
- gstack / BMAD / superpowers / compound-engineering / Codex CLI를 점검하고
- 수동으로 더 해야 할 게 뭔지 정확히 알려줍니다.

### 설치 모드

| 모드 | 동작 |
|------|------|
| `commands-only` | 가장 안전. 슬래시 커맨드만 복사. 훅 없음. `settings.json` 손 안 댐. |
| `safe` (권장) | `commands-only` + 훅 복사 + 안전 훅만 활성화 (위험 git 차단, 세션 시작 브랜치 분기). auto-commit 켜지 **않습니다**. |
| `full` | `safe` + auto-save / auto-commit 활성화. v0.1.1부터 훅은 `main`/`master`, 위험한 파일(`.env`, 키류, `~/.claude/settings.json`), 시크릿 패턴, 삭제 변경, 30개 초과 변경 시 커밋을 거부합니다. 그 모든 체크를 통과해도 여전히 `git add -A`를 실행해서 워킹 트리의 관련 없는 변경까지 스테이징할 수 있습니다. 파워 유저용; 설치 스크립트가 먼저 경고합니다. |

> **글로벌 훅 주의.** `safe`나 `full` 모드에서 설치되는 훅은 `~/.claude`에 있어서 이 사용자 계정의 **모든** Claude Code 세션에 적용됩니다. 이 프로젝트에서만 격리하고 싶으면 `commands-only`를 쓰세요.

### 먼저 안전하게 시도해 보기

게이트가 파일을 건드리기 전에 audit-only 모드로 먼저 돌려보세요:

```
/hwan-refactor-idea --audit-only
/hwan-refactor-code --audit-only
/hwan-refactor-design --audit-only
/hwan-refactor-git --audit-only
```

가장 안전한 설치:

```bash
./install.sh --mode commands-only
```

### 선택적 통합

`doctor.sh` / `doctor.ps1`이 설치 여부와 설치 방법을 알려줍니다:

- **gstack** — `~/.claude/skills/gstack`에 클론 (또는 `--bootstrap` 사용)
- **BMAD** — 프로젝트마다 `npx bmad-method install` (항상 수동, 프로젝트별)
- **superpowers**, **compound-engineering** — Claude Code의 `/plugins` UI로 설치 (항상 수동)
- **Codex CLI** — `npm install -g @openai/codex` (또는 `--bootstrap --bootstrap-codex`)

doctor는 `READY`, `PARTIAL`, `ACTION REQUIRED` 중 하나로 끝납니다.

### Opt-in 부트스트랩 (v0.1.1 신규)

기본 설치는 외부 도구를 절대 건드리지 않습니다. `--bootstrap`
(PowerShell은 `-Bootstrap`)을 명시적으로 넘기면 안전한 자동 설치를
시도합니다:

```bash
./install.sh --mode safe --bootstrap                  # 대화형
./install.sh --mode safe --bootstrap --yes            # 비대화형
./install.sh --mode safe --bootstrap --bootstrap-codex
```
```powershell
.\install.ps1 -Mode safe -Bootstrap
.\install.ps1 -Mode safe -Bootstrap -Yes
.\install.ps1 -Mode safe -Bootstrap -BootstrapCodex
```

자동 설치 대상: **gstack** 클론+setup, 그리고 `--bootstrap-codex` 시
`npm install -g @openai/codex`. 자동 설치 불가: **BMAD**(프로젝트별),
**superpowers** / **compound-engineering**(Claude Code 플러그인 UI 필요).
이들은 정확한 명령어와 함께 수동 단계로 안내됩니다.

기존 설치에는 `doctor --fix` / `doctor -Fix`로 같은 패스를 돌릴 수
있습니다:

```bash
./doctor.sh --fix
.\doctor.ps1 -Fix
```

## 4개 게이트

| 게이트 | 명령어 | 언제 |
|-------|--------|------|
| 1 PRD | `/hwan-refactor-idea` | PRD 작성 직후 |
| 2 코드 | `/hwan-refactor-code` | 개발 중간, 코드 리뷰가 필요할 때 |
| 3 디자인 | `/hwan-refactor-design` | UI 구현 후 UX 점검 |
| 4 릴리스 | `/hwan-refactor-git` | 배포/PR 직전 |

각 명령어 내부 단계 (대략):
```
Phase 0: 이전 학습 로드
Phase 1-3: 다관점 병렬 감사 (gstack + BMAD)
Phase 4-5: 우선순위 계획 (P0/P1/P2/P3)
Phase 6+: 수정 적용 (테스트 검증, 가능하면 회귀 시 롤백)
Phase 7+: 이번 세션 학습 캡처
```

### 공통 옵션

```bash
/hwan-refactor-code              # 기본 파이프라인
/hwan-refactor-code --quick      # 핵심만 빠르게
/hwan-refactor-code --audit-only # 검증만, 자동 수정 안 함
/hwan-refactor-code --dry-run    # 미리보기
/hwan-refactor-code --resume     # 중단된 곳부터 이어서
```

## 안전 모델

Vibekit이 하는 것과 안 하는 것.

**모드와 무관하게 절대 자동으로 안 함:**
- 리모트에 푸시
- PR 생성
- 브랜치 머지
- 배포

**`--mode safe` 선택 시 추가:**
- PreToolUse 훅으로 위험한 git 명령(`git reset --hard`, `git push --force`, `git clean -f`, `main`/`master` 직접 커밋) 차단
- 세션이 `main`/`master`에서 시작되면 자동으로 `claude/session-*` 브랜치 생성
- `~/.claude/settings.json`은 수정 전 항상 백업

**`--mode full`에서 추가:**
- 파일 수정 후 auto-save / auto-commit. 훅은 `main`/`master`, 위험 파일(`.env`, `*.pem`, `*.key`, `~/.claude/settings.json` 등), 시크릿 패턴(`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `BEGIN PRIVATE KEY`, `sk-…`), 삭제 변경(`HWAN_AUTOSAVE_ALLOW_DELETIONS=1`로 허용), `HWAN_AUTOSAVE_MAX_FILES`(기본 30) 초과 시 커밋을 거부합니다. 통과해도 여전히 `git add -A`로 워킹 트리 전체를 스테이징해서 관련 없는 변경까지 같이 커밋할 수 있습니다. 설치 스크립트가 먼저 명시적으로 경고합니다. 끄려면 `HWAN_AUTOSAVE_DISABLE=1` 또는 `safe`/`commands-only`로 다시 설치하세요.

테스트 검증, 롤백, TDD 우선, 프로젝트별 학습 노트는 기반 스킬들(gstack, BMAD, superpowers, compound-engineering)에서 옵니다 — doctor가 알려주는 대로 따로 설치하세요.

## 사용 예시

```bash
# 1. PRD는 직접 작성
vim PRD.md

# 2. 점검
claude
> /hwan-refactor-idea

# 3. 코딩 시작 (AI 도움, 본인이 지휘)
> PRD대로 사용자 인증 구현

# 4. 개발 중간 점검
> /hwan-refactor-code

# 5. UI 구현 후
> /hwan-refactor-design

# 6. 배포 직전
> /hwan-refactor-git

# 7. PR 생성/머지 결정은 본인이
gh pr create
```

## 문서

- [설치 가이드](docs/INSTALLATION.md)
- [보안 & 설치 모드](docs/SECURITY.md)
- [품질 게이트 워크플로우](docs/QUALITY-GATES.md)
- [아키텍처](docs/ARCHITECTURE.md)
- [Cursor / Aider / Cline / Continue 비교](docs/COMPARISON.md)
- [예시 실행 (참고용)](docs/EXAMPLE-RUN.md)
- [Changelog](CHANGELOG.md) • [Roadmap](ROADMAP.md) • [Contributing](CONTRIBUTING.md)

## 기여

[CONTRIBUTING.md](CONTRIBUTING.md) 참고. v0.1.x가 안정화되는 동안에는 작고 집중된 PR이 가장 좋습니다. 특히 환영:
- 번역
- 설치 스크립트 스모크 테스트
- 더 정확한 플러그인 감지
- 프로젝트 단위 설치 모드

## 라이선스

MIT. 자유롭게 사용.

## 크레딧

- [gstack](https://github.com/garrytan/gstack) — Garry Tan
- [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) — BMad Code
- [superpowers](https://github.com/obra/superpowers) — Jesse Vincent (obra)
- [compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) — EveryInc

영감: [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills).
