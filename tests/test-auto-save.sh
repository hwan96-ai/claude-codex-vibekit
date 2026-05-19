#!/usr/bin/env bash
# Tests for .claude/hooks/auto-save.sh and auto-save-payload.py.
#
# Creates a throwaway git repo in $TMPDIR and exercises:
#   - payload mode: stages only the listed file
#   - payload mode: preserves multiple listed files
#   - payload mode: preserves a listed filename containing spaces
#   - payload mode refusal when no payload is provided
#   - auto mode falls back to git add -A when no payload
#   - outside-repo path in payload is rejected (helper drops it; mode=payload
#     then refuses to commit because no valid paths remain)
#   - kill switch (HWAN_AUTOSAVE_DISABLE=1) exits immediately
#   - risky file path still refused under payload mode

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/.claude/hooks/auto-save.sh"
HELPER="$ROOT/.claude/hooks/auto-save-payload.py"
PYTHON_BIN=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && PYTHON_BIN="$c" && break; done
if [ -z "$PYTHON_BIN" ]; then
  echo "python required for auto-save tests" >&2
  exit 2
fi

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

fail=0
say() { printf '  %s %s\n' "$1" "$2"; }
expect_pass() { if [ "$1" -eq 0 ]; then say ok "$2"; else say FAIL "$2"; fail=$((fail+1)); fi; }
expect_fail() { if [ "$1" -ne 0 ]; then say ok "$2"; else say FAIL "$2"; fail=$((fail+1)); fi; }

mkrepo() {
  rm -rf "$WORK/repo" && mkdir -p "$WORK/repo"
  ( cd "$WORK/repo" && \
    git init -q -b feature/test && \
    git config user.email t@example.com && \
    git config user.name test && \
    echo seed > seed.txt && \
    git add seed.txt && \
    git commit -q -m seed )
}

# 1. payload mode: stages only listed file
mkrepo
( cd "$WORK/repo" && echo a > a.txt && echo b > b.txt )
PAYLOAD=$(cat <<JSON
{"tool_input":{"file_path":"a.txt"}}
JSON
)
HWAN_AUTOSAVE_STAGE_MODE=payload bash -c "cd '$WORK/repo' && printf '%s' '$PAYLOAD' | bash '$HOOK'" >/dev/null 2>&1
last_msg=$(cd "$WORK/repo" && git log -1 --pretty=%s 2>/dev/null || true)
files_in_commit=$(cd "$WORK/repo" && git show --name-only --pretty='' HEAD 2>/dev/null | tr '\n' ' ')
case "$last_msg" in
  autosave:*)
    case "$files_in_commit" in
      *a.txt*)
        case "$files_in_commit" in
          *b.txt*) say FAIL "payload mode stages only listed file (got: $files_in_commit)"; fail=$((fail+1)) ;;
          *)       say ok "payload mode stages only listed file" ;;
        esac ;;
      *) say FAIL "payload mode: commit missing a.txt (got: $files_in_commit)"; fail=$((fail+1)) ;;
    esac ;;
  *) say FAIL "payload mode: no autosave commit created (last: $last_msg)"; fail=$((fail+1)) ;;
esac

# 2. payload mode preserves multiple listed files
mkrepo
( cd "$WORK/repo" && echo a > a.txt && echo b > b.txt && echo c > c.txt )
PAYLOAD='{"tool_input":{"files":["a.txt","b.txt"]}}'
HWAN_AUTOSAVE_STAGE_MODE=payload bash -c "cd '$WORK/repo' && printf '%s' '$PAYLOAD' | bash '$HOOK'" >/dev/null 2>&1
last_msg=$(cd "$WORK/repo" && git log -1 --pretty=%s 2>/dev/null || true)
files_in_commit=$(cd "$WORK/repo" && git show --name-only --pretty='' HEAD 2>/dev/null | tr '\n' ' ')
case "$last_msg" in
  autosave:*)
    case "$files_in_commit" in
      *a.txt*b.txt*|*b.txt*a.txt*)
        case "$files_in_commit" in
          *c.txt*) say FAIL "payload mode preserves multiple files without staging extras (got: $files_in_commit)"; fail=$((fail+1)) ;;
          *)       say ok "payload mode preserves multiple listed files" ;;
        esac ;;
      *) say FAIL "payload mode: commit missing a.txt or b.txt (got: $files_in_commit)"; fail=$((fail+1)) ;;
    esac ;;
  *) say FAIL "payload mode: no autosave commit created for multiple files (last: $last_msg)"; fail=$((fail+1)) ;;
esac

# 3. payload mode preserves a filename containing spaces
mkrepo
( cd "$WORK/repo" && echo hello > "hello world.txt" && echo other > other.txt )
PAYLOAD='{"tool_input":{"file_path":"hello world.txt"}}'
HWAN_AUTOSAVE_STAGE_MODE=payload bash -c "cd '$WORK/repo' && printf '%s' '$PAYLOAD' | bash '$HOOK'" >/dev/null 2>&1
last_msg=$(cd "$WORK/repo" && git log -1 --pretty=%s 2>/dev/null || true)
files_in_commit=$(cd "$WORK/repo" && git show --name-only --pretty='' HEAD 2>/dev/null | tr '\n' ' ')
case "$last_msg" in
  autosave:*)
    case "$files_in_commit" in
      *"hello world.txt"*)
        case "$files_in_commit" in
          *other.txt*) say FAIL "payload mode stages spaced filename without staging extras (got: $files_in_commit)"; fail=$((fail+1)) ;;
          *)           say ok "payload mode preserves filename containing spaces" ;;
        esac ;;
      *) say FAIL "payload mode: commit missing spaced filename (got: $files_in_commit)"; fail=$((fail+1)) ;;
    esac ;;
  *) say FAIL "payload mode: no autosave commit created for spaced filename (last: $last_msg)"; fail=$((fail+1)) ;;
esac

# 4. payload mode refuses with no payload
mkrepo
( cd "$WORK/repo" && echo a > a.txt )
HWAN_AUTOSAVE_STAGE_MODE=payload bash -c "cd '$WORK/repo' && echo '' | bash '$HOOK'" >/dev/null 2>&1
last_msg=$(cd "$WORK/repo" && git log -1 --pretty=%s 2>/dev/null || true)
case "$last_msg" in
  seed) say ok "payload mode refuses when no payload" ;;
  *)    say FAIL "payload mode should have refused (last commit: $last_msg)"; fail=$((fail+1)) ;;
esac

# 5. all mode (fallback) stages all changes
mkrepo
( cd "$WORK/repo" && echo a > a.txt && echo b > b.txt )
HWAN_AUTOSAVE_STAGE_MODE=all bash -c "cd '$WORK/repo' && bash '$HOOK' < /dev/null" >/dev/null 2>&1
files_in_commit=$(cd "$WORK/repo" && git show --name-only --pretty='' HEAD 2>/dev/null | tr '\n' ' ')
case "$files_in_commit" in
  *a.txt*b.txt*|*b.txt*a.txt*) say ok "all mode stages all changed files" ;;
  *) say FAIL "all mode: expected a.txt and b.txt (got: $files_in_commit)"; fail=$((fail+1)) ;;
esac

# 6. Outside-repo path in payload is dropped; payload mode then refuses
mkrepo
( cd "$WORK/repo" && echo a > a.txt )
PAYLOAD='{"tool_input":{"file_path":"/etc/passwd"}}'
HWAN_AUTOSAVE_STAGE_MODE=payload bash -c "cd '$WORK/repo' && printf '%s' '$PAYLOAD' | bash '$HOOK'" >/dev/null 2>&1
last_msg=$(cd "$WORK/repo" && git log -1 --pretty=%s 2>/dev/null || true)
case "$last_msg" in
  seed) say ok "outside-repo payload path rejected (payload mode refused)" ;;
  *)    say FAIL "outside-repo payload should have caused refusal (last commit: $last_msg)"; fail=$((fail+1)) ;;
esac

# 7. Kill switch
mkrepo
( cd "$WORK/repo" && echo a > a.txt )
HWAN_AUTOSAVE_DISABLE=1 bash -c "cd '$WORK/repo' && bash '$HOOK' < /dev/null" >/dev/null 2>&1
last_msg=$(cd "$WORK/repo" && git log -1 --pretty=%s 2>/dev/null || true)
case "$last_msg" in
  seed) say ok "kill switch (HWAN_AUTOSAVE_DISABLE=1) exits without commit" ;;
  *)    say FAIL "kill switch should have prevented commit (last: $last_msg)"; fail=$((fail+1)) ;;
esac

# 8. Risky file path is rejected even in payload mode
mkrepo
( cd "$WORK/repo" && echo "OPENAI_API_KEY=x" > .env )
PAYLOAD='{"tool_input":{"file_path":".env"}}'
HWAN_AUTOSAVE_STAGE_MODE=payload bash -c "cd '$WORK/repo' && printf '%s' '$PAYLOAD' | bash '$HOOK'" >/dev/null 2>&1
last_msg=$(cd "$WORK/repo" && git log -1 --pretty=%s 2>/dev/null || true)
case "$last_msg" in
  seed) say ok "risky path (.env) refused under payload mode" ;;
  *)    say FAIL "risky path should have been refused (last: $last_msg)"; fail=$((fail+1)) ;;
esac

echo
if [ "$fail" -gt 0 ]; then
  echo "FAILED: $fail case(s)"
  exit 1
fi
echo "All auto-save tests passed."
