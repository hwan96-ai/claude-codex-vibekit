#!/usr/bin/env bash
# Verify that SHA256SUMS matches the current tree, and that bash + PowerShell
# generators (when both are present) produce byte-identical output.
#
# Run from repo root:  bash tests/test-checksums.sh
# Exit non-zero on failure.

set -u

cd "$(dirname "$0")/.."

fail=0

echo "[1/3] bash generator --check ..."
if bash scripts/generate-checksums.sh --check; then
  echo "  ok"
else
  echo "  FAIL: SHA256SUMS does not match current tree"
  fail=$((fail+1))
fi

echo
echo "[2/3] required files in SHA256SUMS ..."
required=(
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
for f in "${required[@]}"; do
  if grep -F "  $f" SHA256SUMS >/dev/null 2>&1; then
    echo "  ok   $f"
  else
    echo "  FAIL missing in SHA256SUMS: $f"
    fail=$((fail+1))
  fi
done

echo
echo "[3/3] cross-tool parity (bash vs PowerShell, skipped if pwsh absent) ..."
if command -v pwsh >/dev/null 2>&1; then
  bash_out=$(bash scripts/generate-checksums.sh --stdout)
  pwsh_out=$(pwsh -NoProfile -File scripts/generate-checksums.ps1 -Stdout 2>/dev/null)
  if [ "$bash_out" = "$pwsh_out" ]; then
    echo "  ok   bash and PowerShell generators produce identical output"
  else
    echo "  FAIL bash and PowerShell generators disagree"
    diff <(printf '%s' "$bash_out") <(printf '%s' "$pwsh_out") || true
    fail=$((fail+1))
  fi
else
  echo "  skip pwsh not available"
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "FAILED ($fail check(s))"
  exit 1
fi
echo "All checksum tests passed."
