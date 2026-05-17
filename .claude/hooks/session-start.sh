#!/bin/bash

# git 저장소 아니면 조용히 종료
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# 현재 브랜치 확인
branch=$(git branch --show-current 2>/dev/null)

# main/master가 아니면 그대로 사용
if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
  echo "🌿 현재 브랜치: $branch (안전)"
  exit 0
fi

# main/master면 새 브랜치 자동 생성
new_branch="claude/session-$(date '+%Y%m%d-%H%M%S')"

if git checkout -b "$new_branch" 2>/dev/null; then
  echo "🌿 main 브랜치 감지 → 새 브랜치 자동 생성: $new_branch"
  echo "   원본 브랜치($branch)는 안전하게 보존됨"
else
  echo "⚠️  브랜치 생성 실패 (수동으로 만들어주세요: git checkout -b claude/작업명)"
fi

exit 0
