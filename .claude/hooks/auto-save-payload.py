#!/usr/bin/env python3
"""Parse Claude Code hook stdin JSON and emit a NUL-separated list of file
paths that are *safely* inside the current git work tree.

Used by auto-save.sh when HWAN_AUTOSAVE_STAGE_MODE is auto or payload.

Behavior:
- Read JSON from stdin. On any error, exit 0 with empty stdout (caller will
  fall back to its default mode).
- Collect candidate paths from a small set of known fields under tool_input:
    file_path, filePath, path, files (list), edits[].file_path, edits[].path
- Resolve each candidate against the git work tree root.
- Reject paths that:
    * are not absolute resolvable to a real file currently on disk
      (unless --allow-missing is set, which is not used here),
    * fall outside the git work tree,
    * resolve to a directory.
- Print accepted, deduplicated, repo-relative paths separated by NUL.

This is intentionally conservative. The hook contract from Claude Code is not
guaranteed across versions; if anything looks off, we emit nothing and the
caller falls back to its existing `git add -A` path (which already has
secret/risk safeguards).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from typing import Iterable, List


def _git_toplevel() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=2,
        )
        if out.returncode == 0:
            return out.stdout.strip()
    except Exception:
        pass
    return ""


def _walk(node, out: List[str]) -> None:
    if isinstance(node, dict):
        for k in ("file_path", "filePath", "path"):
            v = node.get(k)
            if isinstance(v, str) and v:
                out.append(v)
        files = node.get("files")
        if isinstance(files, list):
            for f in files:
                if isinstance(f, str) and f:
                    out.append(f)
                elif isinstance(f, dict):
                    _walk(f, out)
        edits = node.get("edits")
        if isinstance(edits, list):
            for e in edits:
                if isinstance(e, dict):
                    _walk(e, out)
    elif isinstance(node, list):
        for n in node:
            _walk(n, out)


def collect(payload) -> List[str]:
    """Return raw candidate path strings from common hook payload shapes."""
    out: List[str] = []
    if not isinstance(payload, dict):
        return out
    ti = payload.get("tool_input")
    if isinstance(ti, dict):
        _walk(ti, out)
    return out


def filter_paths(candidates: Iterable[str], top: str) -> List[str]:
    if not top:
        return []
    top_abs = os.path.realpath(top)
    accepted: List[str] = []
    seen = set()
    for c in candidates:
        if not isinstance(c, str) or not c:
            continue
        # Resolve relative paths against the git toplevel.
        if os.path.isabs(c):
            p = c
        else:
            p = os.path.join(top_abs, c)
        try:
            real = os.path.realpath(p)
        except Exception:
            continue
        # Must live inside the git work tree.
        try:
            common = os.path.commonpath([real, top_abs])
        except ValueError:
            continue
        if common != top_abs:
            continue
        # Must exist as a file. (We do not currently support deletion via
        # payload; auto-save.sh handles deletions through its existing guard.)
        if not os.path.isfile(real):
            continue
        rel = os.path.relpath(real, top_abs)
        # Normalize path separators to forward slashes for git on Windows.
        rel = rel.replace(os.sep, "/")
        if rel in seen:
            continue
        seen.add(rel)
        accepted.append(rel)
    return accepted


def main() -> int:
    try:
        data = sys.stdin.read()
        payload = json.loads(data) if data.strip() else {}
    except Exception:
        return 0
    cands = collect(payload)
    if not cands:
        return 0
    top = _git_toplevel()
    accepted = filter_paths(cands, top)
    if not accepted:
        return 0
    sys.stdout.write("\0".join(accepted))
    return 0


if __name__ == "__main__":
    sys.exit(main())
