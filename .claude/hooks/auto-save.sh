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

# Collect the candidate file list (working tree + index + untracked, excluding
# ignored). Use NUL-separated porcelain output so spaces, quotes, and other
# unusual path characters do not distort safety checks.
status_entries=()
status_codes=()
paths=()
while IFS= read -r -d '' entry; do
  [ -z "$entry" ] && continue
  code="${entry:0:2}"
  path="${entry:3}"
  status_entries+=("$entry")
  status_codes+=("$code")
  paths+=("$path")

  # For rename/copy records, porcelain -z emits the old path as the next NUL
  # record. Include it in path-based risk checks, but do not count it as a
  # separate changed file.
  case "$code" in
    R*|C*)
      if IFS= read -r -d '' old_path; then
        [ -n "$old_path" ] && paths+=("$old_path")
      fi
      ;;
  esac
done < <(git status --porcelain=v1 -z 2>/dev/null)

if [ "${#status_entries[@]}" -eq 0 ]; then
  exit 0
fi
changed_count="${#status_entries[@]}"

max_files="${HWAN_AUTOSAVE_MAX_FILES:-30}"
if [ "$changed_count" -gt "$max_files" ] 2>/dev/null; then
  echo "auto-save: refusing — $changed_count files changed, limit is $max_files (HWAN_AUTOSAVE_MAX_FILES)." >&2
  exit 0
fi

# Refuse on deletions unless explicitly allowed.
if [ "${HWAN_AUTOSAVE_ALLOW_DELETIONS:-0}" != "1" ]; then
  for code in "${status_codes[@]}"; do
    case "$code" in
      D*|?D)
        echo "auto-save: refusing — deletions detected. Set HWAN_AUTOSAVE_ALLOW_DELETIONS=1 to allow." >&2
        exit 0
        ;;
    esac
  done
fi

# Refuse on obvious secret / risky file paths.
risky_match=$(printf '%s\n' "${paths[@]}" | grep -E -i \
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
  # Untracked files: scan up to ~64KB each to keep this cheap.
  while IFS= read -r -d '' u; do
    [ -z "$u" ] && continue
    [ -f "$u" ] || continue
    if head -c 65536 "$u" 2>/dev/null | grep -E -q "$secret_pattern"; then
      secret_hit=1
      break
    fi
  done < <(git ls-files --others --exclude-standard -z 2>/dev/null)
fi
if [ "$secret_hit" -eq 1 ]; then
  echo "auto-save: refusing — diff appears to contain a secret or access token." >&2
  exit 0
fi

# Summarize, then commit.
echo "auto-save: branch=$branch files=$changed_count"
printf '%s\n' "${paths[@]}" | sed 's/^/  /'

git add -A
if git diff --cached --quiet; then
  exit 0
fi
git commit -m "autosave: claude changes $(date '+%Y-%m-%d %H:%M:%S')" --quiet || {
  echo "auto-save: git commit failed (hooks? identity?). Skipping." >&2
  exit 0
}

exit 0
