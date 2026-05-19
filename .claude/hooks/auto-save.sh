#!/bin/bash
#
# auto-save.sh — runs after Claude Code Edit/Write/MultiEdit when registered
# in `full` install mode.
#
# Staging modes (HWAN_AUTOSAVE_STAGE_MODE, default: auto):
#   auto     — try to read changed file paths from the hook payload (stdin
#              JSON). If a non-empty, validated list is found, stage ONLY
#              those paths. Otherwise fall back to guarded `git add -A`.
#   payload  — require a valid payload file list; refuse to commit if absent.
#   all      — skip payload parsing and use guarded `git add -A` directly.
#
# In every mode, the existing safeguards still apply before any commit:
#
#   - not inside a git repo                       → exit 0
#   - current branch is main/master               → exit 0
#   - risky file paths in change set              → refuse
#     (.env, .env.*, *.pem, *.key, *.p12, *.pfx, id_rsa, id_ed25519,
#      .claude/settings.json, .claude/settings.local.json)
#   - obvious value-bearing secret/access-token patterns in diff → refuse
#     (API key assignments, private keys, GitHub/GitLab/Slack tokens, sk-…)
#   - change set > HWAN_AUTOSAVE_MAX_FILES (30)   → refuse
#   - any deletions, unless HWAN_AUTOSAVE_ALLOW_DELETIONS=1
#
# Kill switch: HWAN_AUTOSAVE_DISABLE=1 makes this hook exit immediately.
#
# WARNING: the `all` (and `auto` fallback) paths still stage the entire
# working tree after the safeguards. Most users should stay on `--mode safe`.

if [ "${HWAN_AUTOSAVE_DISABLE:-0}" = "1" ]; then
  exit 0
fi

# Read stdin payload once (may be empty).
PAYLOAD=""
if [ ! -t 0 ]; then
  PAYLOAD="$(cat 2>/dev/null || true)"
fi

PAYLOAD_PATHS_FILE=""
cleanup_payload_paths_file() {
  if [ -n "$PAYLOAD_PATHS_FILE" ]; then
    rm -f "$PAYLOAD_PATHS_FILE"
  fi
}
trap cleanup_payload_paths_file EXIT

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch=$(git branch --show-current 2>/dev/null)
case "$branch" in
  main|master|MAIN|MASTER)
    echo "auto-save: refusing to commit on protected branch '$branch'. Create a feature branch." >&2
    exit 0
    ;;
esac

if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
  exit 0
fi

STAGE_MODE="${HWAN_AUTOSAVE_STAGE_MODE:-auto}"
case "$STAGE_MODE" in
  auto|payload|all) ;;
  *)
    echo "auto-save: invalid HWAN_AUTOSAVE_STAGE_MODE='$STAGE_MODE' (auto|payload|all)." >&2
    exit 0
    ;;
esac

# ---- Optional payload-aware staging ----
if [ "$STAGE_MODE" != "all" ] && [ -n "$PAYLOAD" ]; then
  PYTHON_BIN=""
  for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1; then PYTHON_BIN="$cand"; break; fi
  done
  HELPER=""
  for p in \
    "$(dirname "$0")/auto-save-payload.py" \
    "$HOME/.claude/hooks/auto-save-payload.py"; do
    if [ -f "$p" ]; then HELPER="$p"; break; fi
  done
  if [ -n "$PYTHON_BIN" ] && [ -n "$HELPER" ]; then
    PAYLOAD_PATHS_FILE="$(mktemp "${TMPDIR:-/tmp}/vibekit-payload-paths.XXXXXX")" || PAYLOAD_PATHS_FILE=""
    if [ -n "$PAYLOAD_PATHS_FILE" ]; then
      # Helper prints NUL-separated repo-relative paths on success. Keep that
      # output in a file because Bash variables cannot preserve NUL bytes.
      printf '%s' "$PAYLOAD" | "$PYTHON_BIN" "$HELPER" >"$PAYLOAD_PATHS_FILE" 2>/dev/null || true
      if [ ! -s "$PAYLOAD_PATHS_FILE" ]; then
        rm -f "$PAYLOAD_PATHS_FILE"
        PAYLOAD_PATHS_FILE=""
      fi
    fi
  fi
fi

if [ "$STAGE_MODE" = "payload" ] && [ -z "$PAYLOAD_PATHS_FILE" ]; then
  echo "auto-save: refusing — HWAN_AUTOSAVE_STAGE_MODE=payload but no valid payload file list found." >&2
  exit 0
fi

USE_PAYLOAD=0
if [ -n "$PAYLOAD_PATHS_FILE" ]; then
  USE_PAYLOAD=1
fi

# ---- Compute the change set we'll evaluate safeguards against ----
# In payload mode, that is the payload list intersected with git's view of
# what's actually changed. In fallback, it's git's full porcelain view.
changed_lines=$(git status --porcelain=v1 2>/dev/null | sed '/^$/d')
if [ -z "$changed_lines" ]; then
  exit 0
fi

if [ "$USE_PAYLOAD" -eq 1 ]; then
  # Convert NUL-separated payload paths into newline-separated for matching.
  paths=$(tr '\0' '\n' < "$PAYLOAD_PATHS_FILE" | sed '/^$/d')
else
  paths=$(printf '%s\n' "$changed_lines" | awk '{ s=substr($0,4); print s }')
fi
changed_count=$(printf '%s\n' "$paths" | wc -l | tr -d ' ')

max_files="${HWAN_AUTOSAVE_MAX_FILES:-30}"
if [ "$changed_count" -gt "$max_files" ] 2>/dev/null; then
  echo "auto-save: refusing — $changed_count files changed, limit is $max_files (HWAN_AUTOSAVE_MAX_FILES)." >&2
  exit 0
fi

# Refuse on deletions (only meaningful in fallback mode; payload helper rejects
# non-existent files already).
if [ "$USE_PAYLOAD" -eq 0 ] && [ "${HWAN_AUTOSAVE_ALLOW_DELETIONS:-0}" != "1" ]; then
  if printf '%s\n' "$changed_lines" | awk '{print substr($0,1,2)}' | grep -E '^.D|^D.' >/dev/null 2>&1; then
    echo "auto-save: refusing — deletions detected. Set HWAN_AUTOSAVE_ALLOW_DELETIONS=1 to allow." >&2
    exit 0
  fi
fi

# Refuse on risky file paths.
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

# Secret patterns in the (full) diff. Even in payload mode this is a cheap
# extra check against accidental commits.
secret_pattern='((OPENAI_API_KEY|ANTHROPIC_API_KEY|AWS_SECRET_ACCESS_KEY|AWS_SESSION_TOKEN)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}|BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY|sk-[A-Za-z0-9]{8,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9_]{20,}|gho_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,})'
secret_hit=0
if git diff --no-color 2>/dev/null | grep -E -q "$secret_pattern"; then
  secret_hit=1
fi
if [ "$secret_hit" -eq 0 ]; then
  if git diff --cached --no-color 2>/dev/null | grep -E -q "$secret_pattern"; then
    secret_hit=1
  fi
fi
if [ "$secret_hit" -eq 0 ]; then
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    [ -f "$u" ] || continue
    if head -c 65536 "$u" 2>/dev/null | grep -E -q "$secret_pattern"; then
      secret_hit=1
      break
    fi
  done <<EOF
$(git ls-files --others --exclude-standard 2>/dev/null)
EOF
fi
if [ "$secret_hit" -eq 1 ]; then
  echo "auto-save: refusing — diff appears to contain a secret or access token." >&2
  exit 0
fi

if [ "$USE_PAYLOAD" -eq 1 ]; then
  echo "auto-save: branch=$branch files=$changed_count (payload)"
else
  echo "auto-save: branch=$branch files=$changed_count (fallback: git add -A)"
fi
printf '%s\n' "$paths" | sed 's/^/  /'

if [ "$USE_PAYLOAD" -eq 1 ]; then
  # Stage only the payload-listed files.
  # shellcheck disable=SC2086
  while IFS= read -r p; do
    [ -n "$p" ] && git add -- "$p" 2>/dev/null || true
  done <<EOF
$paths
EOF
else
  git add -A
fi

if git diff --cached --quiet; then
  exit 0
fi
git commit -m "autosave: claude changes $(date '+%Y-%m-%d %H:%M:%S')" --quiet || {
  echo "auto-save: git commit failed (hooks? identity?). Skipping." >&2
  exit 0
}

exit 0
