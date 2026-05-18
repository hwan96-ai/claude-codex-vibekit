#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required for smoke tests"
}

require bash
require git

PYTHON_BIN=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v "$cand")"
    break
  fi
done
[ -n "$PYTHON_BIN" ] || fail "python is required for smoke tests"

echo "[1] safe install writes executable hook runtimes"
export CLAUDE_HOME="$TMP_ROOT/claude-home"
"$ROOT/install.sh" --mode safe >/tmp/vibekit-install.out
"$PYTHON_BIN" - "$CLAUDE_HOME/settings.json" <<'PY'
import json, os, shlex, shutil, sys

settings = sys.argv[1]
with open(settings, "r", encoding="utf-8") as f:
    hooks = json.load(f).get("hooks", {})

commands = []
for entries in hooks.values():
    for entry in entries:
        for hook in entry.get("hooks", []):
            cmd = hook.get("command", "")
            if any(name in cmd for name in ("block-dangerous-git.py", "session-start.sh")):
                commands.append(cmd)

if len(commands) != 2:
    raise SystemExit(f"expected 2 safety hook commands, got {len(commands)}: {commands}")

for cmd in commands:
    exe = shlex.split(cmd, posix=True)[0]
    if not (os.path.exists(exe) or shutil.which(exe)):
        raise SystemExit(f"hook runtime is not executable: {cmd}")
PY

echo "[2] full install writes executable hook runtimes"
export CLAUDE_HOME="$TMP_ROOT/claude-home-full"
"$ROOT/install.sh" --mode full >/tmp/vibekit-install-full.out
"$PYTHON_BIN" - "$CLAUDE_HOME/settings.json" <<'PY'
import json, os, shlex, shutil, sys

settings = sys.argv[1]
with open(settings, "r", encoding="utf-8") as f:
    hooks = json.load(f).get("hooks", {})

commands = []
for entries in hooks.values():
    for entry in entries:
        for hook in entry.get("hooks", []):
            cmd = hook.get("command", "")
            if any(name in cmd for name in ("block-dangerous-git.py", "session-start.sh", "auto-save.sh")):
                commands.append(cmd)

if len(commands) != 3:
    raise SystemExit(f"expected 3 full-mode hook commands, got {len(commands)}: {commands}")

for cmd in commands:
    exe = shlex.split(cmd, posix=True)[0]
    if not (os.path.exists(exe) or shutil.which(exe)):
        raise SystemExit(f"hook runtime is not executable: {cmd}")
PY

echo "[3] protected branch commit is blocked"
repo="$TMP_ROOT/protected-repo"
mkdir "$repo"
cp "$ROOT/.claude/hooks/block-dangerous-git.py" "$repo/block-dangerous-git.py"
(
  cd "$repo"
  git init -q
  git checkout -b main >/dev/null
  payload='{"tool_input":{"command":"git commit -m test"}}'
  set +e
  printf '%s' "$payload" | "$PYTHON_BIN" ./block-dangerous-git.py >/tmp/vibekit-block.out 2>/tmp/vibekit-block.err
  code=$?
  set -e
  [ "$code" -eq 2 ] || fail "expected protected branch block exit 2, got $code"
)

echo "[4] placeholder secret names do not block autosave"
repo="$TMP_ROOT/autosave-repo"
mkdir "$repo"
cp "$ROOT/.claude/hooks/auto-save.sh" "$repo/auto-save.sh"
(
  cd "$repo"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  git checkout -b feature/test >/dev/null
  git add auto-save.sh
  git commit -m init -q
  echo 'Document placeholder: OPENAI_API_KEY' > docs.txt
  bash ./auto-save.sh >/tmp/vibekit-autosave-placeholder.out 2>/tmp/vibekit-autosave-placeholder.err
  git log --oneline --max-count=1 | grep -q 'autosave:' || fail "placeholder doc was not autosaved"
)

echo "[5] real-looking secret assignments still block autosave"
repo="$TMP_ROOT/autosave-secret-repo"
mkdir "$repo"
cp "$ROOT/.claude/hooks/auto-save.sh" "$repo/auto-save.sh"
(
  cd "$repo"
  git init -q
  git config user.email test@example.com
  git config user.name Test
  git checkout -b feature/test >/dev/null
  git add auto-save.sh
  git commit -m init -q
  echo 'OPENAI_API_KEY=sk-1234567890abcdefghijklmnop' > secret.txt
  bash ./auto-save.sh >/tmp/vibekit-autosave-secret.out 2>/tmp/vibekit-autosave-secret.err
  git status --porcelain | grep -q 'secret.txt' || fail "secret assignment should remain uncommitted"
)

echo "PASS"
