#!/usr/bin/env python3
# Generate SHA256SUMS from committed/staged git blob contents.
#
# Why this exists:
# - On Windows with core.autocrlf=true, the working tree may contain CRLF
#   versions of tracked release files, even though .gitattributes pins eol=lf.
#   Hashing those CRLF files produces values that break Linux verification.
# - This helper hashes the *git blob* for each release file (always LF-normalized
#   for tracked files with eol=lf), which is what `sha256sum -c` against a
#   Linux checkout will reproduce.
#
# Usage:
#   python3 scripts/checksums-from-blobs.py            # writes ./SHA256SUMS
#   python3 scripts/checksums-from-blobs.py --check    # verifies existing SHA256SUMS
#   python3 scripts/checksums-from-blobs.py --stdout   # prints to stdout
#
# Notes:
# - Reads the release file list from scripts/generate-checksums.sh so the bash
#   generator remains the single source of truth.
# - Files must be staged (`git add <file>`) for `git show :file` to resolve
#   the new content. Unstaged changes are intentionally invisible to this tool.
# - Does NOT replace generate-checksums.sh. Linux/CI should keep using the
#   bash generator. Use this on Windows or when CRLF artifacts in the working
#   tree would otherwise produce wrong hashes.

import hashlib
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GENERATOR = REPO_ROOT / "scripts" / "generate-checksums.sh"
SUMS = REPO_ROOT / "SHA256SUMS"


def read_release_files() -> list[str]:
    text = GENERATOR.read_text(encoding="utf-8")
    match = re.search(r"^FILES=\(\s*\n(.*?)^\)", text, re.DOTALL | re.MULTILINE)
    if not match:
        sys.exit(f"error: could not parse FILES=(...) from {GENERATOR}")
    files = []
    for line in match.group(1).splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        m = re.match(r'"([^"]+)"', s)
        if m:
            files.append(m.group(1))
    if not files:
        sys.exit("error: parsed empty file list from generate-checksums.sh")
    return files


def blob_sha(path: str) -> str:
    try:
        out = subprocess.run(
            ["git", "show", f":{path}"],
            cwd=REPO_ROOT,
            capture_output=True,
            check=True,
        ).stdout
    except subprocess.CalledProcessError as e:
        msg = e.stderr.decode("utf-8", errors="replace").strip()
        sys.exit(f"error: git show :{path} failed: {msg}")
    return hashlib.sha256(out).hexdigest()


def build_sums(files: list[str]) -> str:
    lines = [f"{blob_sha(f)}  {f}" for f in files]
    lines.sort(key=lambda line: line.split("  ", 1)[1])
    return "\n".join(lines) + "\n"


def main() -> int:
    mode = "write"
    if len(sys.argv) > 2:
        sys.exit(f"unknown args: {sys.argv[2:]}")
    if len(sys.argv) == 2:
        arg = sys.argv[1]
        if arg in ("-h", "--help"):
            print(__doc__)
            return 0
        if arg == "--check":
            mode = "check"
        elif arg == "--stdout":
            mode = "stdout"
        elif arg == "":
            mode = "write"
        else:
            sys.exit(f"unknown arg: {arg}")

    files = read_release_files()
    generated = build_sums(files)

    if mode == "stdout":
        sys.stdout.buffer.write(generated.encode("utf-8"))
        return 0
    if mode == "write":
        SUMS.write_bytes(generated.encode("utf-8"))
        print(f"wrote SHA256SUMS ({len(files)} files) from git blobs")
        return 0
    if mode == "check":
        if not SUMS.exists():
            sys.exit("error: SHA256SUMS not present in repo root")
        existing = SUMS.read_bytes().decode("utf-8")
        if existing == generated:
            print(f"ok: SHA256SUMS matches git blob contents ({len(files)} files)")
            return 0
        print("FAIL: SHA256SUMS does not match git blob contents", file=sys.stderr)
        import difflib

        diff = difflib.unified_diff(
            existing.splitlines(keepends=True),
            generated.splitlines(keepends=True),
            fromfile="SHA256SUMS (on disk)",
            tofile="SHA256SUMS (from blobs)",
        )
        sys.stderr.writelines(diff)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
