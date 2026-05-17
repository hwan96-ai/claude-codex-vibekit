#!/bin/bash
#
# auto-save.sh — runs after Claude Code Edit/Write/MultiEdit when registered
# in `full` install mode.
#
# IMPORTANT: this hook still runs `git add -A` on the working tree (it does NOT
# rely on the Claude Code hook payload to identify which files were just
# touched, since that schema is not guaranteed across versions). That means it
# can stage unrelated changes. To make that less dangerous, the hook now
# REFUSES to commit if any of the following are true:
#
#   - not inside a git repo
#   - current branch is main/master
#   - staged or working-tree changes include obvious secret/risky files
#     (.env, .env.*, *.pem, *.key, *.p12, *.pfx, id_rsa, id_ed25519,
#      .claude/settings.json, .claude/settings.local.json)
#   - diff contains obvious secret patterns
#     (OPENAI_API_KEY, ANTHROPIC_API_KEY, BEGIN PRIVATE KEY, sk-)
#   - changed file count exceeds HWAN_AUTOSAVE_MAX_FILES (default 30)
#   - any files were deleted, unless HWAN_AUTOSAVE_ALLOW_DELETIONS=1
#
# Set HWAN_AUTOSAVE_DISABLE=1 to disable the hook entirely without uninstalling.
#
# If that tradeoff is wrong for you, install with `--mode safe` or
# `--mode commands-only` instead.

# Allow user kill switch.
if [ "${HWAN_AUTOSAVE_DISABLE:-0}" = "1" ]; then
  exit 0
fi

# Must be inside a git work tree.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Never auto-commit on protected branches.
branch=$(git branch --show-current 2>/dev/null)
case "$branch" in
  main|master|MAIN|MASTER)
    echo "auto-save: refusing to commit on protected branch '$branch'. Create a feature branch." >&2
    exit 0
    ;;
esac

# Nothing to do?
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
  exit 0
fi

# Collect the candidate file list (working tree + index + untracked, excluding ignored).
# Each porcelain line is "XY <path>" where XY are status codes. Paths with
# unusual characters may appear quoted; that is fine for risky-name detection
# and is far simpler than parsing NUL-separated output here.
changed_lines=$(git status --porcelain=v1 2>/dev/null | sed '/^$/d')
if [ -z "$changed_lines" ]; then
  exit 0
fi
changed_count=$(printf '%s\n' "$changed_lines" | wc -l | tr -d ' ')

max_files="${HWAN_AUTOSAVE_MAX_FILES:-30}"
if [ "$changed_count" -gt "$max_files" ] 2>/dev/null; then
  echo "auto-save: refusing — $changed_count files changed, limit is $max_files (HWAN_AUTOSAVE_MAX_FILES)." >&2
  exit 0
fi

# Extract just the path portion (porcelain v1 with -z: first 3 chars are "XY ").
paths=$(printf '%s\n' "$changed_lines" | awk '{ s=substr($0,4); print s }')

# Refuse on deletions unless explicitly allowed.
if [ "${HWAN_AUTOSAVE_ALLOW_DELETIONS:-0}" != "1" ]; then
  if printf '%s\n' "$changed_lines" | awk '{print substr($0,1,2)}' | grep -E '^.D|^D.' >/dev/null 2>&1; then
    echo "auto-save: refusing — deletions detected. Set HWAN_AUTOSAVE_ALLOW_DELETIONS=1 to allow." >&2
    exit 0
  fi
fi

# Refuse on obvious secret / risky file paths.
risky_match=$(printf '%s\n' "$paths" | grep -E -i \
  -e '(^|/)\.env(\..+)?$' \
  -e '(^|/)[^/]+\.(pem|key|p12|pfx)$' \
  -e '(^|/)(id_rsa|id_ed25519)(\..*)?$' \
  -e '(^|/)\.claude/settings(\.local)?\.json$' \
  || true)
if [ -n "$risky_match" ]; then
  echo "auto-save: refusing — risky file(s) in change set:" >&2
  printf '  %s\n' $risky_match >&2
  exit 0
fi

# Refuse on obvious secret patterns inside the diff (tracked + untracked).
# We scan the combined diff plus untracked file contents (best-effort, capped).
secret_hit=0
if git diff --no-color 2>/dev/null | grep -E -q '(OPENAI_API_KEY|ANTHROPIC_API_KEY|BEGIN PRIVATE KEY|sk-[A-Za-z0-9]{8,})'; then
  secret_hit=1
fi
if [ "$secret_hit" -eq 0 ]; then
  if git diff --cached --no-color 2>/dev/null | grep -E -q '(OPENAI_API_KEY|ANTHROPIC_API_KEY|BEGIN PRIVATE KEY|sk-[A-Za-z0-9]{8,})'; then
    secret_hit=1
  fi
fi
if [ "$secret_hit" -eq 0 ]; then
  # Untracked files: scan up to ~64KB each to keep this cheap.
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    [ -f "$u" ] || continue
    if head -c 65536 "$u" 2>/dev/null | grep -E -q '(OPENAI_API_KEY|ANTHROPIC_API_KEY|BEGIN PRIVATE KEY|sk-[A-Za-z0-9]{8,})'; then
      secret_hit=1
      break
    fi
  done <<EOF
$(git ls-files --others --exclude-standard 2>/dev/null)
EOF
fi
if [ "$secret_hit" -eq 1 ]; then
  echo "auto-save: refusing — diff appears to contain a secret (API key or private key)." >&2
  exit 0
fi

# Summarize, then commit.
echo "auto-save: branch=$branch files=$changed_count"
printf '%s\n' "$paths" | sed 's/^/  /'

git add -A
if git diff --cached --quiet; then
  exit 0
fi
git commit -m "autosave: claude changes $(date '+%Y-%m-%d %H:%M:%S')" --quiet || {
  echo "auto-save: git commit failed (hooks? identity?). Skipping." >&2
  exit 0
}

exit 0
