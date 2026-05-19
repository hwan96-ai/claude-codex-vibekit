#!/usr/bin/env python3
"""Self-contained tests for .claude/hooks/block-dangerous-git.py.

Run with:  python tests/test-block-dangerous-git.py

No external test framework needed. Exit code is non-zero on failure.
"""

from __future__ import annotations

import importlib.util
import json
import os
import pathlib
import subprocess
import sys

# Korean block reasons may not encode in the default Windows code page (cp1252).
# Reconfigure stdout/stderr to UTF-8 best-effort; if unavailable, fall through
# to whatever the platform provides.
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

ROOT = pathlib.Path(__file__).resolve().parent.parent
HOOK_PATH = ROOT / ".claude" / "hooks" / "block-dangerous-git.py"

spec = importlib.util.spec_from_file_location("block_dangerous_git", HOOK_PATH)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)  # type: ignore[union-attr]

failures: list[str] = []


def record(ok: bool, label: str, detail: str = "") -> None:
    if ok:
        print(f"  ok   {label}")
    else:
        suffix = f": {detail}" if detail else ""
        print(f"  FAIL {label}{suffix}")
        failures.append(label)


def assert_eval(command: str, branch: str, want_blocked: bool, label: str) -> None:
    blocked, reason = mod.evaluate(command, branch=branch)
    record(
        blocked == want_blocked,
        label,
        f"command={command!r} branch={branch!r} blocked={blocked!r} reason={reason!r}",
    )


def assert_main(command: str, branch: str, want_code: int, label: str) -> None:
    env = os.environ.copy()
    env["VIBEKIT_HOOK_TEST_BRANCH"] = branch
    payload = json.dumps({"tool_input": {"command": command}})
    proc = subprocess.run(
        [sys.executable, str(HOOK_PATH)],
        input=payload,
        text=True,
        capture_output=True,
        env=env,
        check=False,
    )
    record(
        proc.returncode == want_code,
        label,
        f"exit={proc.returncode} stderr={proc.stderr!r}",
    )


def run() -> int:
    print("Import safety:")
    record(hasattr(mod, "evaluate"), "module imports and exposes evaluate()")
    record(hasattr(mod, "main"), "module imports and exposes main()")

    print("\nBlocked dangerous git commands:")
    for cmd in [
        "git push --force",
        "git push -f",
        "git push --force-with-lease",
        "git push origin +main",
        "git push origin +master",
        "git push origin main",
        "git push origin master",
        "git push origin HEAD:main",
        "git push origin HEAD:master",
        "git -C repo reset --hard",
        "git -C repo clean -fd",
        "git -C repo push origin main",
        "git -c core.safecrlf=false reset --hard",
        "git --git-dir .git --work-tree . reset --hard",
        "git --git-dir=.git --work-tree=. reset --hard",
        "git --no-pager reset --hard",
        "git push origin HEAD:refs/heads/main",
        "git push origin feature:main",
        "git push origin +refs/heads/main",
        "git commit --amend",
        "git branch -D old-branch",
        "git clean -f",
        "git clean -fd",
        "git reset --hard",
    ]:
        assert_eval(cmd, "feature/test", True, f"block: {cmd!r}")

    print("\nAllowed commands and prose:")
    for cmd in [
        "git push origin feature-branch",
        'gh pr create --body "git clean -f"',
        'echo "git push --force"',
        'echo "ok && git reset --hard"',
        'echo "git clean -fd; git reset --hard"',
        'gh pr create --body "Run git reset --hard && git clean -fd if needed"',
        "cat <<EOF\nThis documents git reset --hard.\nEOF",
        "cat <<EOF\nrun git reset --hard && git clean -fd\nEOF",
    ]:
        assert_eval(cmd, "feature/test", False, f"allow: {cmd!r}")

    print("\nProtected ref forms:")
    for ref in [
        "main",
        "refs/heads/main",
        "HEAD:main",
        "HEAD:refs/heads/main",
        "feature:main",
        "feature:refs/heads/main",
        "+main",
        "+refs/heads/main",
    ]:
        assert_eval(f"git push origin {ref}", "feature/test", True, f"block protected ref: {ref}")

    print("\nProtected branch local mutation policy:")
    for cmd in [
        "git commit -m 'wip'",
        "git merge feature/x",
        "git reset --mixed HEAD~1",
        "git clean -n",
    ]:
        assert_eval(cmd, "main", True, f"block local mutation on main: {cmd!r}")
        assert_eval(cmd, "master", True, f"block local mutation on master: {cmd!r}")
    assert_eval(
        "git push origin feature-branch",
        "main",
        False,
        "allow feature branch push even when current branch is main",
    )

    print("\nMulti-command segments:")
    assert_eval(
        "echo ok && git reset --hard",
        "feature/test",
        True,
        "block git command after &&",
    )
    assert_eval(
        'echo "git reset --hard" && echo done',
        "feature/test",
        False,
        "allow quoted dangerous prose in non-git segments",
    )
    assert_eval(
        "cd repo && git clean -fd",
        "feature/test",
        True,
        "block git command after cd &&",
    )
    assert_eval(
        "echo ok; git reset --hard",
        "feature/test",
        True,
        "block git command after semicolon",
    )

    print("\nScript entrypoint:")
    assert_main("git status --short", "feature/test", 0, "main() allows harmless command")
    assert_main("git push --force", "feature/test", 2, "main() blocks dangerous command")
    assert_main("git commit -m test", "main", 2, "main() honors branch override")

    print("\nEnv var override:")
    os.environ["VIBEKIT_HOOK_TEST_BRANCH"] = "main"
    try:
        record(mod.current_branch() == "main", "current_branch() reads VIBEKIT_HOOK_TEST_BRANCH")
    finally:
        del os.environ["VIBEKIT_HOOK_TEST_BRANCH"]

    print()
    if failures:
        print(f"FAILED: {len(failures)} case(s)")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    print("All cases passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
