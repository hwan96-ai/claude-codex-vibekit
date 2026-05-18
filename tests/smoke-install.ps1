# Installer smoke test (PowerShell).
# Installs into an isolated CLAUDE_HOME, runs doctor, asserts all five
# vibekit commands were copied. Doctor exit 0 (READY) or 1 (PARTIAL) is
# acceptable; exit 2 (ACTION REQUIRED) is a failure.
#
# Required env: $env:CLAUDE_HOME
# Optional env: $env:VIBEKIT_SMOKE_MODE  (default commands-only)
#               $env:VIBEKIT_SMOKE_SCOPE (default global)

$ErrorActionPreference = "Stop"

if (-not $env:CLAUDE_HOME) {
    Write-Error "smoke-install.ps1: CLAUDE_HOME must be set to an isolated path"
    exit 2
}

$mode  = if ($env:VIBEKIT_SMOKE_MODE)  { $env:VIBEKIT_SMOKE_MODE }  else { 'commands-only' }
$scope = if ($env:VIBEKIT_SMOKE_SCOPE) { $env:VIBEKIT_SMOKE_SCOPE } else { 'global' }

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Write-Host "smoke: repo_root=$repoRoot"
Write-Host "smoke: claude_home=$env:CLAUDE_HOME"
Write-Host "smoke: mode=$mode scope=$scope"

New-Item -ItemType Directory -Path $env:CLAUDE_HOME -Force | Out-Null

# Use an explicit Claude home path and run from a neutral workdir (never the
# repo root) so the in-repo warning path never triggers.
$workdir = Join-Path ([System.IO.Path]::GetTempPath()) ("vibekit-smoke-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $workdir -Force | Out-Null

try {
    Push-Location $workdir
    try {
        if ($scope -eq 'project') {
            & (Join-Path $repoRoot 'install.ps1') -Mode $mode -Scope project -ClaudeHome $env:CLAUDE_HOME -Yes
        } else {
            & (Join-Path $repoRoot 'install.ps1') -Mode $mode -ClaudeHome $env:CLAUDE_HOME
        }
        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Write-Error "smoke: install.ps1 exited $LASTEXITCODE"
            exit 1
        }

        if ($scope -eq 'project') {
            & (Join-Path $repoRoot 'doctor.ps1') -Scope project -ClaudeHome $env:CLAUDE_HOME -CI
        } else {
            & (Join-Path $repoRoot 'doctor.ps1') -ClaudeHome $env:CLAUDE_HOME -CI
        }
        $doctorRc = $LASTEXITCODE
        Write-Host "smoke: doctor rc=$doctorRc"
        if ($doctorRc -ge 2) {
            Write-Error "smoke: FAIL doctor reported ACTION REQUIRED"
            exit 1
        }
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $workdir
}

$cmdDir = Join-Path $env:CLAUDE_HOME "commands"

$expected = @(
    'hwan-refactor-idea.md',
    'hwan-refactor-code.md',
    'hwan-refactor-design.md',
    'hwan-refactor-git.md',
    'git-safe.md'
)
$missing = 0
foreach ($f in $expected) {
    $p = Join-Path $cmdDir $f
    if (-not (Test-Path $p)) {
        Write-Host "smoke: FAIL missing $p"
        $missing++
    }
}
if ($missing -gt 0) { exit 1 }
Write-Host "smoke: PASS ($cmdDir has all 5 commands; doctor rc=$doctorRc)"
exit 0
