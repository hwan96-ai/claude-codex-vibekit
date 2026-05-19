#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import sys

PROTECTED_BRANCHES = {"main", "master"}
PROTECTED_REFS = {"main", "master", "refs/heads/main", "refs/heads/master"}


def current_branch():
    override = os.environ.get("VIBEKIT_HOOK_TEST_BRANCH")
    if override is not None:
        return override
    try:
        return subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            check=False,
            text=True,
        ).stdout.strip()
    except Exception:
        return ""


def strip_heredoc_bodies(command):
    lines = command.splitlines()
    kept = []
    pending_delimiter = None
    for line in lines:
        if pending_delimiter:
            if line.strip() == pending_delimiter:
                pending_delimiter = None
            continue
        kept.append(line)
        marker = _find_heredoc_delimiter(line)
        if marker:
            pending_delimiter = marker
    return "\n".join(kept)


def _find_heredoc_delimiter(line):
    try:
        tokens = shlex.split(line, comments=False, posix=True)
    except ValueError:
        return None
    for index, token in enumerate(tokens):
        if token in {"<<", "<<-"} and index + 1 < len(tokens):
            return tokens[index + 1]
        if token.startswith("<<-") and len(token) > 3:
            return token[3:]
        if token.startswith("<<") and len(token) > 2:
            return token[2:]
    return None


def split_command_segments(command):
    command = strip_heredoc_bodies(command)
    segments = []
    current = []
    quote = None
    escaped = False
    index = 0
    while index < len(command):
        char = command[index]
        if escaped:
            current.append(char)
            escaped = False
            index += 1
            continue
        if char == "\\":
            current.append(char)
            escaped = True
            index += 1
            continue
        if quote:
            current.append(char)
            if char == quote:
                quote = None
            index += 1
            continue
        if char in {"'", '"'}:
            current.append(char)
            quote = char
            index += 1
            continue
        if command.startswith("&&", index) or command.startswith("||", index):
            _append_segment(segments, current)
            current = []
            index += 2
            continue
        if char in {";", "\n"}:
            _append_segment(segments, current)
            current = []
            index += 1
            continue
        current.append(char)
        index += 1
    _append_segment(segments, current)
    return segments


def _append_segment(segments, chars):
    segment = "".join(chars).strip()
    if segment:
        segments.append(segment)


def segment_argv(segment):
    try:
        return shlex.split(segment, comments=False, posix=True)
    except ValueError:
        return []


def short_option_has(arg, flag):
    return arg.startswith("-") and not arg.startswith("--") and flag in arg[1:]


def is_protected_ref(ref):
    candidate = ref[1:] if ref.startswith("+") else ref
    destination = candidate.rsplit(":", 1)[-1]
    if destination in PROTECTED_REFS:
        return True
    return False


def git_subcommand_and_args(argv):
    index = 1
    while index < len(argv):
        arg = argv[index]
        # -c takes a key=value pair as the NEXT token. Handle three cases:
        #   1. Well-formed `-c key=value …` → consume both tokens.
        #   2. Malformed `-c <destructive-verb> …` (e.g. `git -c reset --hard`,
        #      `git -c push origin main`) → consume only `-c` so the verb
        #      remains visible to the destructive-subcommand detector.
        #   3. Malformed `-c <junk> <destructive-verb> …` (e.g.
        #      `git -c foo reset --hard`) → consume both `-c` and the junk
        #      so the verb that follows becomes the detected subcommand.
        # Keep the destructive-verb set in sync with evaluate_git_argv().
        if arg == "-c" and index + 1 < len(argv):
            nxt = argv[index + 1]
            if "=" in nxt:
                index += 2
                continue
            if nxt in {"reset", "clean", "push", "commit", "merge", "branch"}:
                index += 1
                continue
            index += 2
            continue
        if arg in {"-C", "--git-dir", "--work-tree"} and index + 1 < len(argv):
            index += 2
            continue
        if arg.startswith("-C") and len(arg) > 2:
            index += 1
            continue
        if arg.startswith("--git-dir=") or arg.startswith("--work-tree="):
            index += 1
            continue
        if arg == "--no-pager":
            index += 1
            continue
        return arg, argv[index + 1:]
    return "", []


def evaluate_git_argv(argv, branch):
    if len(argv) < 2:
        return False, ""

    subcommand, args = git_subcommand_and_args(argv)

    if branch.lower() in PROTECTED_BRANCHES and subcommand in {"commit", "merge", "reset", "clean"}:
        return True, f"{branch} 브랜치 직접 조작"

    if subcommand == "push":
        for arg in args:
            if arg == "--force" or arg.startswith("--force-with-lease"):
                return True, "git push force (원격 강제 덮어쓰기)"
            if short_option_has(arg, "f"):
                return True, "git push -f (원격 강제 덮어쓰기)"
            # --mirror replaces every ref on the remote with local refs,
            # including deleting remote refs that no longer exist locally.
            # --prune deletes remote refs not present locally. Both can
            # destroy protected branches without naming them explicitly.
            if arg == "--mirror":
                return True, "git push --mirror (원격 ref 전체 덮어쓰기/삭제)"
            if arg == "--prune":
                return True, "git push --prune (로컬에 없는 원격 ref 삭제)"
            if is_protected_ref(arg):
                return True, "protected remote ref 직접 push"
        return False, ""

    if subcommand == "commit" and "--amend" in args:
        return True, "git commit --amend (히스토리 수정)"

    if subcommand == "branch" and "-D" in args:
        return True, "git branch -D (브랜치 강제 삭제)"

    if subcommand == "clean":
        for arg in args:
            if arg == "--force" or short_option_has(arg, "f"):
                return True, "git clean -f (파일 영구 삭제)"
        return False, ""

    if subcommand == "reset" and "--hard" in args:
        return True, "git reset --hard (되돌리기 불가)"

    return False, ""


def evaluate(command, branch=None):
    cmd = command or ""
    if branch is None:
        branch = current_branch()

    for segment in split_command_segments(cmd):
        argv = segment_argv(segment)
        if not argv or argv[0] != "git":
            continue
        blocked, reason = evaluate_git_argv(argv, branch)
        if blocked:
            return True, reason

    return False, ""


def main():
    try:
        data = json.load(sys.stdin)
        cmd = data.get("tool_input", {}).get("command", "")
    except Exception:
        return 0

    blocked, reason = evaluate(cmd)
    if blocked:
        print(f"🚫 차단됨: {reason}", file=sys.stderr)
        print(f"   명령어: {cmd}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
