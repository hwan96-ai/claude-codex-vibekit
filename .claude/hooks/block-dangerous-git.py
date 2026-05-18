#!/usr/bin/env python3
"""PreToolUse:Bash hook that blocks clearly dangerous git operations.

Design goals:
- Block destructive / history-rewriting operations regardless of branch name
  mentioned in the command line (force push, hard reset, dangerous clean,
  forced branch delete, protected-branch deletion via remote, amend, rebase
  on a protected branch).
- Block direct commits / merges on a protected branch (`main`, `master`) by
  inspecting the *current* branch, not by string-matching "main" in the
  command itself.
- DO NOT block normal non-force pushes, even to `main` (e.g.
  `git push origin main`, `git push -u origin main`, `git push origin --tags`).
  Releasing from `main` is a legitimate, intentional action.

Hook contract (Claude Code PreToolUse:Bash):
- Reads a JSON object on stdin with `tool_input.command` (string).
- Exit 0 = allow. Exit 2 with stderr message = block.

Branch detection can be overridden in tests via env var
`VIBEKIT_HOOK_TEST_BRANCH`.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from typing import Iterable, List, Optional, Tuple

PROTECTED_BRANCHES = {"main", "master"}

SHELL_SEPARATORS = {"&&", "||", ";", "|", "&"}


def current_branch() -> str:
    override = os.environ.get("VIBEKIT_HOOK_TEST_BRANCH")
    if override is not None:
        return override.strip()
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if out.returncode == 0:
            return out.stdout.strip()
    except Exception:
        pass
    return ""


def tokenize(cmd: str) -> Tuple[List[str], bool]:
    """Return (tokens, ok). ok=False means shlex failed and tokens are a
    naive whitespace split — caller should use the conservative regex
    fallback in that case.
    """
    try:
        return shlex.split(cmd, posix=True), True
    except ValueError:
        return cmd.split(), False


def find_git_invocations(tokens: List[str]) -> Iterable[List[str]]:
    """Yield argv tokens after each `git` invocation found in the command line.

    The command line is split on shell operators first so that
    `cd foo && git push --force` and `git status; git reset --hard` both surface
    each git call.
    """
    chunk: List[str] = []
    chunks: List[List[str]] = []
    for tok in tokens:
        if tok in SHELL_SEPARATORS:
            if chunk:
                chunks.append(chunk)
                chunk = []
        else:
            chunk.append(tok)
    if chunk:
        chunks.append(chunk)

    for c in chunks:
        for i, t in enumerate(c):
            if t == "git":
                yield c[i + 1 :]
                break


def _has_force_flag(args: List[str]) -> Optional[str]:
    for a in args:
        if a in ("--force", "-f"):
            return a
        if a.startswith("--force-with-lease"):
            return a
    return None


def classify(git_args: List[str], branch: str) -> Tuple[bool, Optional[str]]:
    if not git_args:
        return False, None
    sub = git_args[0]
    rest = git_args[1:]

    if sub == "reset" and "--hard" in rest:
        return True, "git reset --hard (작업 트리/인덱스 영구 되돌리기)"

    if sub == "clean":
        for a in rest:
            if a == "--force":
                return True, "git clean --force (파일 영구 삭제)"
            if a.startswith("-") and not a.startswith("--") and "f" in a:
                return True, f"git clean {a} (파일 영구 삭제)"

    if sub == "checkout":
        if "--" in rest:
            idx = rest.index("--")
            tail = rest[idx + 1 :]
            if tail == ["."]:
                return True, "git checkout -- . (변경사항 전체 취소)"

    if sub == "push":
        flag = _has_force_flag(rest)
        if flag is not None:
            return True, f"git push {flag} (원격 강제 덮어쓰기)"
        # Force-update refspec: any non-option token starting with '+'
        # (e.g. `+main`, `+HEAD:main`, `+feature:main`,
        # `+refs/heads/feature:refs/heads/main`).
        for a in rest:
            if a.startswith("+") and len(a) > 1 and not a.startswith("-"):
                return True, (
                    f"Blocked force push refspec '{a}'. "
                    f"Remove '+' or use a safe push."
                )
        if "--delete" in rest:
            idx = rest.index("--delete")
            for tgt in rest[idx + 1 :]:
                if tgt in PROTECTED_BRANCHES:
                    return True, f"git push --delete {tgt} (원격 보호 브랜치 삭제)"
        for a in rest:
            if a.startswith(":") and len(a) > 1:
                tgt = a[1:]
                if tgt in PROTECTED_BRANCHES:
                    return True, f"git push :{tgt} (원격 보호 브랜치 삭제)"

    if sub == "branch":
        if "-D" in rest:
            return True, "git branch -D (강제 브랜치 삭제)"
        if "--delete" in rest and "--force" in rest:
            return True, "git branch --delete --force (강제 브랜치 삭제)"

    if sub == "commit":
        if "--amend" in rest:
            return True, "git commit --amend (기존 커밋 변경/히스토리 재작성)"
        if branch in PROTECTED_BRANCHES:
            return True, f"보호 브랜치({branch})에서 직접 commit"

    if sub == "merge":
        if branch in PROTECTED_BRANCHES:
            return True, f"보호 브랜치({branch})에서 직접 merge"

    if sub == "rebase" and branch in PROTECTED_BRANCHES:
        return True, f"보호 브랜치({branch})에서 rebase (히스토리 재작성)"

    return False, None


# Conservative regex safety net for cases where shlex tokenization fails or
# clearly destructive shapes slip through. These patterns must only fire on
# unambiguously dangerous shapes — they never look for the literal token "main".
_FALLBACK_PATTERNS: List[Tuple[re.Pattern, str]] = [
    (re.compile(r"\bgit\s+reset\s+(?:[^\n;|&]*\s)?--hard\b"),
        "git reset --hard"),
    (re.compile(r"\bgit\s+clean\s+(?:[^\n;|&]*\s)?-[a-zA-Z]*f[a-zA-Z]*\b"),
        "git clean -f"),
    (re.compile(r"\bgit\s+push\s+(?:[^\n;|&]*\s)?--force(?:-with-lease)?\b"),
        "git push --force"),
    (re.compile(r"\bgit\s+push\s+(?:[^\n;|&]*\s)?-f\b"),
        "git push -f"),
    (re.compile(r"\brm\s+-rf?\s+/(?:\s|$)"),
        "rm -rf /"),
]


def fallback_regex_block(cmd: str) -> Tuple[bool, Optional[str]]:
    for pat, reason in _FALLBACK_PATTERNS:
        if pat.search(cmd):
            return True, reason
    return False, None


def evaluate(cmd: str, branch: str) -> Tuple[bool, Optional[str]]:
    if not cmd:
        return False, None
    # rm -rf / is always dangerous, check first
    if re.search(r"\brm\s+-rf?\s+/(?:\s|$)", cmd):
        return True, "rm -rf / (루트 경로 강제 삭제)"

    tokens, ok = tokenize(cmd)
    if ok:
        for git_args in find_git_invocations(tokens):
            block, reason = classify(git_args, branch)
            if block:
                return True, reason
        return False, None

    # shlex failed — use conservative regex as a safety net.
    return fallback_regex_block(cmd)


def main() -> int:
    try:
        data = json.load(sys.stdin)
        cmd = data.get("tool_input", {}).get("command", "")
    except Exception:
        return 0
    branch = current_branch()
    block, reason = evaluate(cmd, branch)
    if block:
        print(f"🚫 차단됨: {reason}", file=sys.stderr)
        print(f"   명령어: {cmd}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
