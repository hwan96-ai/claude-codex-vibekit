# Generate SHA256SUMS for release-relevant Vibekit files (Windows PowerShell).
#
# Usage:
#   .\scripts\generate-checksums.ps1            # writes .\SHA256SUMS
#   .\scripts\generate-checksums.ps1 -Check     # verifies existing SHA256SUMS
#   .\scripts\generate-checksums.ps1 -Stdout    # prints to stdout (no file write)
#
# Format (one line per file, matching sha256sum output):
#   <sha256>  <relative/path>
#
# Notes:
# - Computes hashes only for the curated release file list below.
# - Fails if any required file is missing.
# - Paths are written with forward slashes so SHA256SUMS matches across
#   platforms (Linux/macOS sha256sum output uses forward slashes).
# - SHA256SUMS verifies release files after clone or download. It does NOT
#   protect against a compromised repository owner account. See docs\SECURITY.md.

[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Stdout
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
Set-Location $RepoRoot

$Files = @(
    ".claude/commands/git-safe.md",
    ".claude/commands/hwan-refactor-code.md",
    ".claude/commands/hwan-refactor-design.md",
    ".claude/commands/hwan-refactor-git.md",
    ".claude/commands/hwan-refactor-idea.md",
    ".claude/hooks/auto-save-payload.py",
    ".claude/hooks/auto-save.sh",
    ".claude/hooks/block-dangerous-git.py",
    ".claude/hooks/session-start.sh",
    "doctor.ps1",
    "doctor.sh",
    "install.ps1",
    "install.sh",
    "uninstall.ps1",
    "uninstall.sh"
) | Sort-Object

# Verify all required files exist before hashing.
$missing = @()
foreach ($f in $Files) {
    if (-not (Test-Path -LiteralPath $f)) { $missing += $f }
}
if ($missing.Count -gt 0) {
    Write-Error "missing required file(s):`n  $($missing -join "`n  ")"
    exit 1
}

$lines = foreach ($f in $Files) {
    $hash = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()
    # Two spaces between hash and path, matching `sha256sum` output style.
    "$hash  $f"
}

if ($Stdout) {
    # Write LF-joined (not CRLF) so byte-for-byte parity with the bash
    # generator holds on Windows. `Write-Output` would translate to CRLF
    # via the console host on Windows PowerShell.
    [Console]::Out.Write((($lines -join "`n") + "`n"))
    exit 0
}

if ($Check) {
    if (-not (Test-Path -LiteralPath 'SHA256SUMS')) {
        Write-Error "SHA256SUMS not present in repo root"
        exit 1
    }
    $current = Get-Content -LiteralPath 'SHA256SUMS' -Encoding UTF8
    # Normalize: trim trailing whitespace, ignore blank lines.
    $cur = $current | Where-Object { $_ -ne '' } | ForEach-Object { $_.TrimEnd() }
    $new = $lines   | ForEach-Object { $_.TrimEnd() }
    $diff = Compare-Object $cur $new
    if ($null -eq $diff) {
        Write-Host "ok: SHA256SUMS matches current tree ($($Files.Count) files)"
        exit 0
    } else {
        Write-Host "FAIL: SHA256SUMS does not match current tree" -ForegroundColor Red
        $diff | ForEach-Object { Write-Host $_ }
        exit 1
    }
}

# Write mode. Use LF line endings + UTF8 (no BOM) so the file matches
# `sha256sum -c SHA256SUMS` exactly on Linux/macOS.
$content = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText((Join-Path $RepoRoot 'SHA256SUMS'), $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "wrote SHA256SUMS ($($Files.Count) files)"
