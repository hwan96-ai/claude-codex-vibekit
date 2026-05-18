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

Push-Location $repoRoot
try {
    if ($scope -eq 'project') {
        & .\install.ps1 -Mode $mode -Scope project -Yes
    } else {
        & .\install.ps1 -Mode $mode
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "smoke: install.ps1 exited $LASTEXITCODE"
        exit 1
    }

    & .\doctor.ps1
    $doctorRc = $LASTEXITCODE
    Write-Host "smoke: doctor rc=$doctorRc"
    if ($doctorRc -ge 2) {
        Write-Error "smoke: FAIL doctor reported ACTION REQUIRED"
        exit 1
    }
} finally {
    Pop-Location
}

if ($scope -eq 'project') {
    $cmdDir = Join-Path $repoRoot ".claude\commands"
} else {
    $cmdDir = Join-Path $env:CLAUDE_HOME "commands"
}

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
