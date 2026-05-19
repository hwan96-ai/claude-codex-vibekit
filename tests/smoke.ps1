param()

$ErrorActionPreference = "Stop"

function Fail($Message) {
    Write-Error $Message
    exit 1
}

function Require($Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Fail "$Name is required for smoke tests"
    }
}

Require git
Require bash

$Python = $null
foreach ($cand in @('python','python3','py')) {
    $cmd = Get-Command $cand -ErrorAction SilentlyContinue
    if ($cmd) { $Python = $cmd.Source; break }
}
if (-not $Python) { Fail "python is required for smoke tests" }

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("vibekit-smoke-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TmpRoot | Out-Null

try {
    Write-Host "[1] safe install writes executable hook runtimes"
    $env:CLAUDE_HOME = Join-Path $TmpRoot "claude-home"
    & (Join-Path $Root "install.ps1") -Mode safe | Out-Null
    $settings = Get-Content (Join-Path $env:CLAUDE_HOME "settings.json") -Raw | ConvertFrom-Json
    $commands = @()
    foreach ($prop in $settings.hooks.PSObject.Properties) {
        foreach ($entry in $prop.Value) {
            foreach ($hook in $entry.hooks) {
                if ($hook.command -match 'block-dangerous-git.py|session-start.sh') {
                    $commands += $hook.command
                }
            }
        }
    }
    if ($commands.Count -ne 2) { Fail "expected 2 safety hook commands, got $($commands.Count)" }
    foreach ($command in $commands) {
        if ($command -match '^"([^"]+)"') { $exe = $matches[1] }
        else { $exe = ($command -split '\s+')[0] }
        if (-not (Test-Path $exe) -and -not (Get-Command $exe -ErrorAction SilentlyContinue)) {
            Fail "hook runtime is not executable: $command"
        }
    }

    Write-Host "[2] full install writes executable hook runtimes"
    $env:CLAUDE_HOME = Join-Path $TmpRoot "claude-home-full"
    & (Join-Path $Root "install.ps1") -Mode full | Out-Null
    $settings = Get-Content (Join-Path $env:CLAUDE_HOME "settings.json") -Raw | ConvertFrom-Json
    $commands = @()
    foreach ($prop in $settings.hooks.PSObject.Properties) {
        foreach ($entry in $prop.Value) {
            foreach ($hook in $entry.hooks) {
                if ($hook.command -match 'block-dangerous-git.py|session-start.sh|auto-save.sh') {
                    $commands += $hook.command
                }
            }
        }
    }
    if ($commands.Count -ne 3) { Fail "expected 3 full-mode hook commands, got $($commands.Count)" }
    foreach ($command in $commands) {
        if ($command -match '^"([^"]+)"') { $exe = $matches[1] }
        else { $exe = ($command -split '\s+')[0] }
        if (-not (Test-Path $exe) -and -not (Get-Command $exe -ErrorAction SilentlyContinue)) {
            Fail "hook runtime is not executable: $command"
        }
    }

    Write-Host "[3] protected branch commit is blocked"
    $repo = Join-Path $TmpRoot "protected-repo"
    New-Item -ItemType Directory -Path $repo | Out-Null
    Copy-Item (Join-Path $Root ".claude\hooks\block-dangerous-git.py") (Join-Path $repo "block-dangerous-git.py")
    Push-Location $repo
    try {
        git init -q
        git checkout -b main | Out-Null
        $payload = '{"tool_input":{"command":"git commit -m test"}}'
        $payload | & $Python .\block-dangerous-git.py *> $null
        if ($LASTEXITCODE -ne 2) { Fail "expected protected branch block exit 2, got $LASTEXITCODE" }
    } finally {
        Pop-Location
    }

    Write-Host "[4] placeholder secret names do not block autosave"
    $repo = Join-Path $TmpRoot "autosave-repo"
    New-Item -ItemType Directory -Path $repo | Out-Null
    Copy-Item (Join-Path $Root ".claude\hooks\auto-save.sh") (Join-Path $repo "auto-save.sh")
    Push-Location $repo
    try {
        git init -q
        git config user.email test@example.com
        git config user.name Test
        git checkout -b feature/test | Out-Null
        git add auto-save.sh
        git commit -m init -q
        Set-Content -Path docs.txt -Value 'Document placeholder: OPENAI_API_KEY'
        bash ./auto-save.sh | Out-Null
        if (-not ((git log --oneline --max-count=1) -match 'autosave:')) {
            Fail "placeholder doc was not autosaved"
        }
    } finally {
        Pop-Location
    }

    Write-Host "[5] real-looking secret assignments still block autosave"
    $repo = Join-Path $TmpRoot "autosave-secret-repo"
    New-Item -ItemType Directory -Path $repo | Out-Null
    Copy-Item (Join-Path $Root ".claude\hooks\auto-save.sh") (Join-Path $repo "auto-save.sh")
    Push-Location $repo
    try {
        git init -q
        git config user.email test@example.com
        git config user.name Test
        git checkout -b feature/test | Out-Null
        git add auto-save.sh
        git commit -m init -q
        Set-Content -Path secret.txt -Value 'OPENAI_API_KEY=sk-1234567890abcdefghijklmnop'
        bash ./auto-save.sh | Out-Null
        if (-not ((git status --porcelain) -match 'secret.txt')) {
            Fail "secret assignment should remain uncommitted"
        }
    } finally {
        Pop-Location
    }

    Write-Host "PASS"
} finally {
    Remove-Item -Recurse -Force $TmpRoot -ErrorAction SilentlyContinue
}
