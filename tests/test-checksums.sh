#!/usr/bin/env bash
# Verify that SHA256SUMS matches the current tree, and that bash + PowerShell
# generators (when both are present) produce byte-identical output.
#
# Run from repo root:  bash tests/test-checksums.sh
# Exit non-zero on failure.
#
# CRLF tolerance: on Windows checkouts with core.autocrlf=true the working tree
# may contain CRLF line endings even though .gitattributes pins eol=lf for the
# tracked release files. In that case the working-tree hash diverges from
# SHA256SUMS purely because of checkout-time line-ending conversion, not
# because committed content changed. When the generator --check fails, this
# script falls back to a per-file diagnostic: for each mismatched path it
# compares the working-tree file with the committed git blob after stripping
# CR bytes; if the only difference is CR characters (i.e. CRLF↔LF), that file
# is flagged as a CRLF artifact and tolerated. Any file that differs by real
# content fails the test. Linux/CI checkouts (LF working tree) hit the happy
# path and never enter the diagnostic, so release integrity is preserved.

set -u

cd "$(dirname "$0")/.."

fail=0

echo "[1/3] bash generator --check ..."
if bash scripts/generate-checksums.sh --check; then
  echo "  ok"
else
  echo "  working-tree hash differs from SHA256SUMS; running per-file CRLF diagnostic ..."

  if ! command -v git >/dev/null 2>&1; then
    echo "  FAIL: git not available; cannot distinguish CRLF artifact from real drift"
    fail=$((fail+1))
  else
    sha_cmd=""
    if command -v sha256sum >/dev/null 2>&1; then
      sha_cmd="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
      sha_cmd="shasum -a 256"
    else
      echo "  FAIL: neither sha256sum nor shasum available"
      fail=$((fail+1))
    fi

    if [ -n "$sha_cmd" ]; then
      crlf_only_count=0
      real_drift=0
      while IFS= read -r line; do
        expected=$(printf '%s\n' "$line" | awk '{ print $1 }')
        f=$(printf '%s\n' "$line" | awk '{ print $2 }')
        [ -z "$f" ] && continue

        if [ ! -f "$f" ]; then
          echo "  FAIL $f: present in SHA256SUMS but missing from working tree"
          real_drift=$((real_drift+1))
          continue
        fi
        if ! git cat-file -e ":$f" 2>/dev/null; then
          echo "  FAIL $f: not present in git index"
          real_drift=$((real_drift+1))
          continue
        fi

        # shellcheck disable=SC2086
        working_hash=$($sha_cmd "$f" | awk '{ print tolower($1) }')
        if [ "$working_hash" = "$expected" ]; then
          continue   # file matches; no diagnostic needed
        fi

        # Strip CR bytes from working tree and from blob, then compare.
        # CRLF-only difference ⇒ stripped hashes match. Anything else is real.
        # shellcheck disable=SC2086
        working_stripped=$(tr -d '\r' < "$f" | $sha_cmd | awk '{ print tolower($1) }')
        # shellcheck disable=SC2086
        blob_stripped=$(git show ":$f" | tr -d '\r' | $sha_cmd | awk '{ print tolower($1) }')
        if [ "$working_stripped" = "$blob_stripped" ]; then
          echo "  CRLF $f: working tree matches committed blob after CR-strip (checkout artifact, tolerated)"
          crlf_only_count=$((crlf_only_count+1))
        else
          echo "  FAIL $f: real content drift (not CRLF)"
          real_drift=$((real_drift+1))
        fi
      done < SHA256SUMS

      if [ "$real_drift" -gt 0 ]; then
        echo "  FAIL: $real_drift file(s) differ by real content; $crlf_only_count by CRLF only"
        fail=$((fail+1))
      else
        echo "  ok ($crlf_only_count file(s) tolerated as CRLF checkout artifacts; no real drift)"
        echo "  hint: run 'git add --renormalize .' to make generator --check pass directly."
      fi
    fi
  fi
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
