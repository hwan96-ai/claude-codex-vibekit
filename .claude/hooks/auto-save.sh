#!/bin/bash
#
# auto-save.sh — runs after Claude Code Edit/Write/MultiEdit when registered
# in `full` install mode. Stages the full working tree (`git add -A`) and
# commits, because the Claude Code hook payload is not relied upon here to
# identify which files were just touched. That keeps the hook robust across
# Claude Code versions, at the cost of also staging unrelated changes.
# If that tradeoff is wrong for you, install with `--mode safe` or
# `--mode commands-only` instead.

# git 저장소 아니면 조용히 종료
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# main/master에서 작업 중이면 경고 후 종료
branch=$(git branch --show-current 2>/dev/null)
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo "⚠️  경고: main 브랜치에서 직접 작업 중입니다. 브랜치를 만들어주세요." >&2
  exit 0
fi

# 변경사항 없으면 종료
if git diff --quiet && git diff --cached --quiet; then
  exit 0
fi

# 자동 저장
git add -A
git commit -m "autosave: $(date '+%Y-%m-%d %H:%M:%S')" --quiet

exit 0
