#!/usr/bin/env python3
"""Self-contained tests for .claude/hooks/block-dangerous-git.py.

Run with:  python tests/test-block-dangerous-git.py

No external test framework needed. Exit code is non-zero on failure.
"""

from __future__ import annotations

import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HOOK_DIR = ROOT / ".claude" / "hooks"
sys.path.insert(0, str(HOOK_DIR))

# Importing a hyphenated filename via importlib so we don't depend on
# python-package naming.
import importlib.util

spec = importlib.util.spec_from_file_location(
    "block_dangerous_git", HOOK_DIR / "block-dangerous-git.py"
)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)  # type: ignore[union-attr]


ALLOWED_ON_FEATURE = [
    "git push origin main",
    "git push origin master",
    "git push -u origin main",
    "git push",
    "git push origin HEAD:main",
    "git push origin feature:main",
    "git push origin v0.1.2",
    "git push origin --tags",
    "git push -u origin feat/example",
    "git push origin feat/foo",
    "git status",
    "git commit -m 'fix main bug'",  # word "main" in commit message
    "git merge feature/x",
    "git checkout -- file.txt",
    'echo "git push --force"',  # quoted, not actually invoking git
]

BLOCKED_ANYWHERE = [
    "git push --force",
    "git push -f",
    "git push --force-with-lease",
    "git push --force-with-lease=origin/main",
    "git push origin main --force",
    "git reset --hard",
    "git reset --hard HEAD~1",
    "git clean -f",
    "git clean -fd",
    "git clean -xdf",
    "git clean -fxd",
    "git clean --force",
    "git push origin --delete main",
    "git push origin :main",
    "git push origin --delete master",
    # Force-update refspecs (the '+' prefix forces a non-fast-forward update).
    "git push origin +main",
    "git push origin +master",
    "git push origin +HEAD:main",
    "git push origin +feature:main",
    "git push origin +feature:master",
    "git push origin +refs/heads/feature:refs/heads/main",
    "git push origin +refs/heads/feature:refs/heads/master",
    "git branch -D feature/foo",
    "git commit --amend",
    "git commit --amend -m 'oops'",
    "git checkout -- .",
    "rm -rf /",
]

BLOCKED_ON_PROTECTED = [
    ("git commit -m 'wip'", "main"),
    ("git commit", "master"),
    ("git merge feature/x", "main"),
    ("git rebase origin/main", "main"),
]


failures = []


def check(name, got, want):
    if got == want:
        print(f"  ok   {name}")
    else:
        print(f"  FAIL {name}: got block={got[0]!r} reason={got[1]!r}, want block={want}")
        failures.append(name)


def run():
    print("Allowed (feature branch, should NOT block):")
    for cmd in ALLOWED_ON_FEATURE:
        block, reason = mod.evaluate(cmd, branch="feature/test")
        if block:
            print(f"  FAIL allow: {cmd!r} -> blocked: {reason}")
            failures.append(f"allow:{cmd}")
        else:
            print(f"  ok   allow: {cmd!r}")

    print("\nAllowed even on main (intentional push):")
    for cmd in [
        "git push origin main",
        "git push -u origin main",
        "git push",
        "git push origin --tags",
        "git push origin v0.1.2",
    ]:
        block, reason = mod.evaluate(cmd, branch="main")
        if block:
            print(f"  FAIL allow-on-main: {cmd!r} -> blocked: {reason}")
            failures.append(f"allow-on-main:{cmd}")
        else:
            print(f"  ok   allow-on-main: {cmd!r}")

    print("\nBlocked regardless of branch:")
    for cmd in BLOCKED_ANYWHERE:
        block, reason = mod.evaluate(cmd, branch="feature/test")
        if not block:
            print(f"  FAIL block: {cmd!r} -> allowed")
            failures.append(f"block:{cmd}")
        else:
            print(f"  ok   block: {cmd!r} ({reason})")

    print("\nBlocked only on protected branch:")
    for cmd, branch in BLOCKED_ON_PROTECTED:
        block, reason = mod.evaluate(cmd, branch=branch)
        if not block:
            print(f"  FAIL block-on-{branch}: {cmd!r} -> allowed")
            failures.append(f"block-on-{branch}:{cmd}")
        else:
            print(f"  ok   block-on-{branch}: {cmd!r} ({reason})")

    # Same commit/merge commands should be allowed on feature branches.
    print("\nProtected-branch-only commands allowed on feature branches:")
    for cmd, _ in BLOCKED_ON_PROTECTED:
        block, reason = mod.evaluate(cmd, branch="feature/test")
        # `git commit --amend` is blocked anywhere (history rewrite), so skip it.
        if "--amend" in cmd:
            continue
        if block:
            print(f"  FAIL allow-on-feature: {cmd!r} -> blocked: {reason}")
            failures.append(f"allow-on-feature:{cmd}")
        else:
            print(f"  ok   allow-on-feature: {cmd!r}")

    # Env var override path.
    print("\nEnv var override (VIBEKIT_HOOK_TEST_BRANCH):")
    os.environ["VIBEKIT_HOOK_TEST_BRANCH"] = "main"
    try:
        b = mod.current_branch()
        if b == "main":
            print("  ok   override returns 'main'")
        else:
            print(f"  FAIL override: got {b!r}")
            failures.append("override")
    finally:
        del os.environ["VIBEKIT_HOOK_TEST_BRANCH"]

    print()
    if failures:
        print(f"FAILED: {len(failures)} case(s)")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("All cases passed.")
    return 0


if __name__ == "__main__":
    sys.exit(run())
