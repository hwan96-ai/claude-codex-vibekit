# Claude-Codex Vibekit Doctor (Windows PowerShell)
# Exit codes: 0 = READY, 1 = PARTIAL, 2 = ACTION REQUIRED

[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$Yes
)

$ErrorActionPreference = "Continue"

function OK($m)   { Write-Host "  ok  $m" -ForegroundColor Green }
function WARN($m) { Write-Host "  --  $m" -ForegroundColor Yellow }
function MISS($m) { Write-Host "  !!  $m" -ForegroundColor Red }

if ($env:CLAUDE_HOME) {
    $ClaudeHome = $env:CLAUDE_HOME
} else {
    $ClaudeHome = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".claude"
}

$requiredMissing = 0
$optionalMissing = 0
$vibekitMissing  = 0

Write-Host "=== Vibekit doctor ===" -ForegroundColor Cyan
Write-Host "claude_home: $ClaudeHome"

Write-Host "`n[required tools]"
foreach ($bin in @('git','node','bash')) {
    $c = Get-Command $bin -ErrorAction SilentlyContinue
    if ($c) {
        $ver = (& $bin --version 2>$null | Select-Object -First 1)
        OK "$bin ($ver)"
    } else {
        MISS "${bin}: not found"
        $requiredMissing++
    }
}

$Python = $null
foreach ($cand in @('python','python3','py')) {
    $c = Get-Command $cand -ErrorAction SilentlyContinue
    if ($c) { $Python = $c.Source; break }
}
if ($Python) {
    $ver = (& $Python --version 2>&1 | Select-Object -First 1)
    OK "$Python ($ver)"
} else {
    MISS "python: not found"
    $requiredMissing++
}

# Node version >= 20
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nv = (& node -v 2>$null) -replace '^v',''
    $major = ($nv -split '\.')[0]
    if ([int]$major -ge 20) {
        OK "node version >= 20 ($nv)"
    } else {
        MISS "node version is $nv; >= 20 required"
        $requiredMissing++
    }
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    OK "claude CLI found"
} else {
    MISS "claude CLI: not found"
    Write-Host "       install (PowerShell): irm https://claude.ai/install.ps1 | iex"
    $requiredMissing++
}

Write-Host "`n[optional tools]"
if (Get-Command codex -ErrorAction SilentlyContinue) {
    $cv = (& codex --version 2>$null | Select-Object -First 1)
    OK "codex ($cv)"
} else {
    WARN "codex: not installed"
    Write-Host "       install: npm install -g @openai/codex"
    $optionalMissing++
}

if (Get-Command npx -ErrorAction SilentlyContinue) {
    & npx --yes bmad-method --version 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        OK "bmad-method available via npx"
    } else {
        WARN "bmad-method: not preinstalled (will install on first use)"
        Write-Host "       to preinstall: npx bmad-method install"
        $optionalMissing++
    }
} else {
    WARN "npx: not available; BMAD requires Node.js"
    $optionalMissing++
}

$gstackDir = Join-Path $ClaudeHome "skills\gstack"
if (Test-Path $gstackDir) {
    OK "gstack: $gstackDir"
} else {
    WARN "gstack: not installed"
    Write-Host "       git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git `"$gstackDir`""
    Write-Host "       cd `"$gstackDir`"; .\setup"
    $optionalMissing++
}

$settingsPath = Join-Path $ClaudeHome "settings.json"
if (Test-Path $settingsPath) {
    $settingsText = Get-Content $settingsPath -Raw
    if ($settingsText -match 'superpowers')          { OK "superpowers: referenced in settings.json" }
    else { WARN "superpowers: not detected (install via Claude Code /plugins)"; $optionalMissing++ }
    if ($settingsText -match 'compound-engineering') { OK "compound-engineering: referenced in settings.json" }
    else { WARN "compound-engineering: not detected (install via Claude Code /plugins)"; $optionalMissing++ }
} else {
    WARN "superpowers / compound-engineering: settings.json absent, cannot detect"
    $optionalMissing += 2
}

Write-Host "`n[vibekit files]"
$cmdFiles = @(
    "commands\hwan-refactor-idea.md",
    "commands\hwan-refactor-code.md",
    "commands\hwan-refactor-design.md",
    "commands\hwan-refactor-git.md",
    "commands\git-safe.md"
)
foreach ($rel in $cmdFiles) {
    $p = Join-Path $ClaudeHome $rel
    if (Test-Path $p) { OK $p } else { MISS "$p missing"; $vibekitMissing++ }
}

$hookFiles = @(
    "hooks\block-dangerous-git.py",
    "hooks\auto-save.sh",
    "hooks\session-start.sh"
)
foreach ($rel in $hookFiles) {
    $p = Join-Path $ClaudeHome $rel
    if (Test-Path $p) { OK $p } else { WARN "$p not installed (safe/full mode installs it)" }
}

if (Test-Path $settingsPath) {
    OK "$settingsPath present"
} else {
    WARN "$settingsPath missing (commands-only mode is fine without it)"
}

Write-Host "`n[settings.json hook entries]"
if ((Test-Path $settingsPath) -and $Python) {
    $py = @'
import json, os, shlex, shutil, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"  !! could not parse settings.json: {e}")
    sys.exit(0)
hooks = (data.get("hooks") or {})
def has(event, contains):
    for entry in hooks.get(event, []) or []:
        for h in entry.get("hooks", []) or []:
            cmd = h.get("command", "")
            if contains in cmd: return cmd
    return None

def command_runtime_available(cmd):
    try:
        parts = shlex.split(cmd, posix=True)
    except ValueError:
        return False
    if not parts:
        return False
    exe = parts[0]
    return os.path.exists(exe) or shutil.which(exe) is not None

checks = [
    ("PreToolUse",  "block-dangerous-git.py", "safety"),
    ("SessionStart","session-start.sh",       "safety"),
    ("PostToolUse", "auto-save.sh",           "auto-commit (full mode only)"),
]
missing_runtime = False
for event, needle, label in checks:
    cmd = has(event, needle)
    if cmd and command_runtime_available(cmd): print(f"  ok  {event}: {label} -> {cmd}")
    elif cmd:
        print(f"  !!  {event}: {label} runtime not found -> {cmd}")
        missing_runtime = True
    else:   print(f"  --  {event}: {label} not configured")
sys.exit(3 if missing_runtime else 0)
'@
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp.FullName -Value $py -Encoding UTF8
    & $Python $tmp.FullName $settingsPath
    if ($LASTEXITCODE -ne 0) { $requiredMissing++ }
    Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
} else {
    WARN "skipped (no settings.json or no python)"
}

if ($Fix) {
    Write-Host "`n[-Fix] Attempting safe automatic fixes" -ForegroundColor Cyan
    Write-Host "Only tools with clear CLI installation flows are auto-installed." -ForegroundColor DarkGray

    function Confirm-Fix($prompt) {
        if ($Yes) { return $true }
        $ans = Read-Host "  $prompt [y/N]"
        return ($ans -match '^(y|Y|yes|YES)$')
    }

    function Invoke-GitCloneWithTimeout($destination, $timeoutSeconds = 120) {
        $args = @('clone', '--single-branch', '--depth', '1', 'https://github.com/garrytan/gstack.git', "`"$destination`"")
        $proc = Start-Process -FilePath 'git' -ArgumentList $args -NoNewWindow -PassThru
        if (-not $proc.WaitForExit($timeoutSeconds * 1000)) {
            try { $proc.Kill() } catch {}
            return 124
        }
        return $proc.ExitCode
    }

    $fxAuto   = New-Object System.Collections.ArrayList
    $fxSkip   = New-Object System.Collections.ArrayList
    $fxManual = New-Object System.Collections.ArrayList
    $fxFail   = New-Object System.Collections.ArrayList

    $gstackDir = Join-Path $ClaudeHome "skills\gstack"
    if (Test-Path $gstackDir) {
        [void]$fxSkip.Add("gstack (already installed)")
    } elseif (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        [void]$fxFail.Add("gstack: git missing")
    } elseif (Confirm-Fix "Clone gstack into $gstackDir and run setup?") {
        New-Item -ItemType Directory -Path (Join-Path $ClaudeHome "skills") -Force | Out-Null
        $cloneExit = Invoke-GitCloneWithTimeout $gstackDir
        if ($cloneExit -eq 0) {
            $setupPath = Join-Path $gstackDir "setup"
            if (Test-Path $setupPath) {
                Push-Location $gstackDir
                try {
                    $bash = Get-Command bash -ErrorAction SilentlyContinue
                    if ($bash) { & bash ./setup } else { & $setupPath }
                    if ($LASTEXITCODE -eq 0) { [void]$fxAuto.Add("gstack") }
                    else { [void]$fxFail.Add("gstack setup: cd $gstackDir; bash ./setup") }
                } finally { Pop-Location }
            } else {
                [void]$fxManual.Add("gstack: cd $gstackDir; .\setup (no setup script auto-detected)")
            }
        } else {
            [void]$fxFail.Add("gstack clone timed out or failed: git clone https://github.com/garrytan/gstack.git `"$gstackDir`"")
        }
    } else {
        [void]$fxSkip.Add("gstack (declined)")
    }

    [void]$fxManual.Add("BMAD: run 'npx bmad-method install' inside your target project")
    [void]$fxManual.Add("superpowers: /plugin marketplace add obra/superpowers-marketplace then /plugin install superpowers@superpowers-marketplace")
    [void]$fxManual.Add("compound-engineering: install via Claude Code or Codex /plugins TUI")
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        [void]$fxManual.Add("codex (optional): npm install -g @openai/codex")
    }

    Write-Host "`n[-Fix] Report" -ForegroundColor Cyan
    if ($fxAuto.Count   -gt 0) { Write-Host "  installed:" -ForegroundColor Green;     $fxAuto   | ForEach-Object { Write-Host "    - $_" } }
    if ($fxSkip.Count   -gt 0) { Write-Host "  skipped:"   -ForegroundColor DarkGray;  $fxSkip   | ForEach-Object { Write-Host "    - $_" } }
    if ($fxManual.Count -gt 0) { Write-Host "  manual:"    -ForegroundColor Yellow;    $fxManual | ForEach-Object { Write-Host "    - $_" } }
    if ($fxFail.Count   -gt 0) { Write-Host "  failures:"  -ForegroundColor Red;       $fxFail   | ForEach-Object { Write-Host "    - $_" } }
    Write-Host "Re-run doctor.ps1 (without -Fix) to see updated status." -ForegroundColor DarkGray
}

Write-Host ""
if ($requiredMissing -gt 0 -or $vibekitMissing -gt 0) {
    Write-Host "ACTION REQUIRED" -ForegroundColor Red
    exit 2
} elseif ($optionalMissing -gt 0) {
    Write-Host "PARTIAL" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "READY" -ForegroundColor Green
    exit 0
}
