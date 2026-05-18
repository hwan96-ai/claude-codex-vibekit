#!/usr/bin/env bash
# Generate SHA256SUMS for release-relevant Vibekit files.
#
# Usage:
#   ./scripts/generate-checksums.sh           # writes ./SHA256SUMS
#   ./scripts/generate-checksums.sh --check   # verifies existing ./SHA256SUMS
#   ./scripts/generate-checksums.sh --stdout  # prints to stdout (no file write)
#
# Format (one line per file):
#   <sha256>  <relative/path>
#
# Notes:
# - Computes hashes only for the curated release file list below. Anything
#   outside the list (e.g. .git, .claude/workflow, .claude/learnings, backups,
#   settings.json) is intentionally excluded.
# - Fails if any required file is missing.
# - SHA256SUMS verifies release files after clone or download. It does NOT
#   protect against a compromised repository owner account. See docs/SECURITY.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FILES=(
  ".claude/commands/git-safe.md"
  ".claude/commands/hwan-refactor-code.md"
  ".claude/commands/hwan-refactor-design.md"
  ".claude/commands/hwan-refactor-git.md"
  ".claude/commands/hwan-refactor-idea.md"
  ".claude/hooks/auto-save-payload.py"
  ".claude/hooks/auto-save.sh"
  ".claude/hooks/block-dangerous-git.py"
  ".claude/hooks/session-start.sh"
  "doctor.ps1"
  "doctor.sh"
  "install.ps1"
  "install.sh"
  "uninstall.ps1"
  "uninstall.sh"
)

MODE="write"
case "${1:-}" in
  --check)  MODE="check" ;;
  --stdout) MODE="stdout" ;;
  "" )      MODE="write" ;;
  -h|--help)
    sed -n '2,18p' "$0"
    exit 0
    ;;
  *)
    echo "unknown arg: $1" >&2
    exit 2
    ;;
esac

# Pick a sha256 tool. sha256sum on Linux/WSL; shasum on macOS.
sha_cmd=""
if command -v sha256sum >/dev/null 2>&1; then
  sha_cmd="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  sha_cmd="shasum -a 256"
else
  echo "error: neither sha256sum nor shasum found" >&2
  exit 2
fi

# Verify all required files are present before hashing.
missing=0
for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "error: missing required file: $f" >&2
    missing=$((missing + 1))
  fi
done
if [ "$missing" -gt 0 ]; then
  echo "error: $missing required file(s) missing; aborting" >&2
  exit 1
fi

# Produce a stable, sorted hash list.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for f in "${FILES[@]}"; do
  # shellcheck disable=SC2086
  $sha_cmd "$f" >> "$tmp"
done
# Normalize: strip the `*` binary-mode marker that sha256sum emits on Git Bash
# for Windows, so the output matches the PowerShell script byte-for-byte
# (`<hash>  <path>` with two spaces, no asterisk). Lowercase the hash to match
# Get-FileHash output.
LC_ALL=C awk '{ h = tolower($1); p = $2; sub(/^\*/, "", p); printf "%s  %s\n", h, p }' "$tmp" \
  | LC_ALL=C sort -k2 > "${tmp}.sorted"
mv "${tmp}.sorted" "$tmp"

case "$MODE" in
  stdout)
    cat "$tmp"
    ;;
  write)
    mv "$tmp" SHA256SUMS
    trap - EXIT
    echo "wrote SHA256SUMS (${#FILES[@]} files)"
    ;;
  check)
    if [ ! -f SHA256SUMS ]; then
      echo "error: SHA256SUMS not present in repo root" >&2
      exit 1
    fi
    if diff -u SHA256SUMS "$tmp" >/dev/null; then
      echo "ok: SHA256SUMS matches current tree (${#FILES[@]} files)"
    else
      echo "FAIL: SHA256SUMS does not match current tree" >&2
      diff -u SHA256SUMS "$tmp" >&2 || true
      exit 1
    fi
    ;;
esac
