#!/usr/bin/env python3
import json
import re
import sys

try:
    data = json.load(sys.stdin)
    cmd = data.get("tool_input", {}).get("command", "")
except Exception:
    sys.exit(0)

blocked = [
    (r"git\s+reset\s+--hard",       "git reset --hard (되돌리기 불가)"),
    (r"git\s+clean\s+-[^\s]*f",     "git clean -f (파일 영구 삭제)"),
    (r"git\s+push\s+.*--force",     "git push --force (원격 강제 덮어쓰기)"),
    (r"git\s+push\s+.*-f\b",        "git push -f (원격 강제 덮어쓰기)"),
    (r"git\s+checkout\s+--\s+\.",   "git checkout -- . (변경사항 전체 취소)"),
    (r"git\s+(merge|push|commit).*\bmain\b",  "main 브랜치 직접 조작"),
    (r"git\s+(merge|push|commit).*\bmaster\b","master 브랜치 직접 조작"),
    (r"rm\s+-rf?\s+/",              "루트 경로 강제 삭제"),
]

for pattern, reason in blocked:
    if re.search(pattern, cmd):
        print(f"🚫 차단됨: {reason}", file=sys.stderr)
        print(f"   명령어: {cmd}", file=sys.stderr)
        sys.exit(2)

sys.exit(0)
