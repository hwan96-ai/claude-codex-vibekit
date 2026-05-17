---
description: 현재 프로젝트에 Git 안전 설정 적용 (Downloads의 claude-git-safe에서 복사)
---

C:\Users\gkwog\Downloads\claude-git-safe 폴더의 Git 안전 설정을 현재 작업 중인 프로젝트에 적용해줘.

## 작업 순서

### 1단계: .claude 폴더 처리
- 현재 프로젝트 루트에 `.claude` 폴더가 있는지 확인
- **없으면**: `C:\Users\gkwog\Downloads\claude-git-safe\.claude` 폴더 전체를 그대로 복사
- **있으면**: 내부 파일을 하나씩 비교해서:
  - 같은 이름 파일이 없으면 복사
  - 같은 이름 파일이 있으면 **절대 덮어쓰지 말고** 어떤 파일이 충돌했는지 사용자에게 보고

### 2단계: CLAUDE.md 처리
- 현재 프로젝트 루트의 `CLAUDE.md` 확인
- **없으면**: `C:\Users\gkwog\Downloads\claude-git-safe\CLAUDE.md` 복사
- **있으면**: 파일 내용을 읽고 "Git 안전 규칙" 또는 "## Git" 섹션이 있는지 확인
  - 이미 있으면: 건드리지 말고 "이미 적용됨"이라고 알려줘
  - 없으면: 파일 끝에 아래 섹션을 추가 (기존 내용은 절대 수정 금지)

```markdown

## Git 안전 규칙
- main, master 브랜치에 직접 커밋/푸시/병합 절대 금지
- 세션 시작 시 현재 브랜치 확인하고, main/master면 즉시 새 브랜치 생성: `claude/YYYYMMDD-작업명`
- 브랜치 병합은 사용자가 직접 결정한다 (묻지도 말고 자동으로 하지 마)
- 다음 명령어 사용 금지: `git reset --hard`, `git push --force`, `git clean -f`, `git checkout main` (사용자가 명시적으로 요청한 경우 제외)
- 작업 단위로 작게, 자주 커밋
```

### 3단계: 현재 브랜치 점검
- `git branch --show-current` 실행
- 결과가 `main` 또는 `master`이면:
  - 경고 메시지 출력
  - 새 브랜치 이름 제안 (예: `claude/{오늘날짜}-{프로젝트맥락에맞는짧은이름}`)
  - 사용자에게 브랜치 생성 여부 확인 후 진행

### 4단계: 최종 보고
다음 형식으로 깔끔하게 요약:

```
✅ 복사된 파일:
  - .claude/settings.json
  - .claude/hooks/...

⏭️  건너뛴 파일 (이미 존재):
  - (있다면 나열)

📝 CLAUDE.md 상태: [신규 생성 / 섹션 추가 / 이미 적용됨]

🌿 현재 브랜치: [브랜치명]
   → [안전 / main이라 새 브랜치 생성함 / 브랜치 생성 필요]
```

## 주의사항
- 기존 파일은 절대 덮어쓰지 마라
- 충돌이 있으면 사용자에게 먼저 보고하고 결정을 기다려라
- 모든 작업은 현재 작업 중인 프로젝트 폴더(cwd) 기준으로 한다
