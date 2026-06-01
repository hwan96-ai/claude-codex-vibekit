# Claude-Codex Vibekit Doctor (Windows PowerShell)
# Exit codes: 0 = READY, 1 = PARTIAL, 2 = ACTION REQUIRED
#
# Sections:
#   [core readiness] / [hook configuration] / [optional integrations]
#   / [recommended next steps]

[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$Yes,
    [switch]$CI,
    [ValidateSet('global','project')]
    [string]$Scope = 'global',
    [string]$ClaudeHome
)

$ErrorActionPreference = "Continue"

function OK($m)   { Write-Host "  ok  $m" -ForegroundColor Green }
function WARN($m) { Write-Host "  --  $m" -ForegroundColor Yellow }
function MISS($m) { Write-Host "  !!  $m" -ForegroundColor Red }
function Section($m) { Write-Host "`n$m" -ForegroundColor Cyan }

if (-not $ClaudeHome) {
    if ($Scope -eq 'project') {
        $ClaudeHome = Join-Path (Get-Location).Path ".claude"
    } elseif ($env:CLAUDE_HOME) {
        $ClaudeHome = $env:CLAUDE_HOME
    } else {
        $ClaudeHome = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".claude"
    }
}

if ($Scope -eq 'project') {
    $SettingsPrimary = Join-Path $ClaudeHome "settings.local.json"
} else {
    $SettingsPrimary = Join-Path $ClaudeHome "settings.json"
}

if ($env:CODEX_HOME) {
    $CodexHome = $env:CODEX_HOME
} else {
    $CodexHome = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex"
}

$requiredMissing  = 0
$optionalMissing  = 0
$vibekitMissing   = 0
$hooksUnparseable = 0
$safeHooksConfigured = 0
$NextSteps = New-Object System.Collections.ArrayList
function AddStep($s) { [void]$NextSteps.Add($s) }

Write-Host "=== Vibekit doctor ===" -ForegroundColor Cyan
Write-Host "scope:       $Scope"
Write-Host "claude_home: $ClaudeHome"
Write-Host "codex_home:  $CodexHome"
Write-Host "settings:    $SettingsPrimary"

Section "[core readiness]"
foreach ($bin in @('git','node','bash')) {
    $c = Get-Command $bin -ErrorAction SilentlyContinue
    if ($c) {
        $ver = (& $bin --version 2>$null | Select-Object -First 1)
        OK "$bin ($ver)"
    } else {
        MISS "${bin}: not found"
        $requiredMissing++
        AddStep "install $bin (required)"
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
    AddStep "install Python 3 (required for installer JSON merge + hooks)"
}

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($nodeCmd) {
    $nv = (& node -v 2>$null) -replace '^v',''
    $major = ($nv -split '\.')[0]
    if ([int]$major -ge 20) {
        OK "node version >= 20 ($nv)"
    } else {
        MISS "node version is $nv; >= 20 required"
        $requiredMissing++
        AddStep "upgrade Node.js to >= 20"
    }
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    OK "claude CLI found"
} elseif ($CI) {
    WARN "claude CLI not found (allowed in CI smoke mode)"
    $optionalMissing++
    AddStep "install Claude Code (skipped in CI): irm https://claude.ai/install.ps1 | iex"
} else {
    MISS "claude CLI: not found"
    $requiredMissing++
    AddStep "install Claude Code: irm https://claude.ai/install.ps1 | iex"
}

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

$codexPromptFiles = @(
    "prompts\hwan-refactor-idea.md",
    "prompts\hwan-refactor-code.md",
    "prompts\hwan-refactor-design.md",
    "prompts\hwan-refactor-git.md"
)
foreach ($rel in $codexPromptFiles) {
    $p = Join-Path $CodexHome $rel
    if (Test-Path $p) { OK $p } else { MISS "$p missing (Codex prompt)"; $vibekitMissing++ }
}

if ($vibekitMissing -gt 0) {
    AddStep "re-run installer: .\install.ps1 -Mode commands-only -Scope $Scope"
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

Section "[hook configuration]"
if (Test-Path $SettingsPrimary) {
    OK "$SettingsPrimary present"
    if ($Python) {
        $py = @'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"PARSE_ERROR:{e}")
    sys.exit(0)
hooks = (data.get("hooks") or {})
def has(event, contains):
    for entry in hooks.get(event, []) or []:
        for h in entry.get("hooks", []) or []:
            cmd = h.get("command", "")
            if contains in cmd: return cmd
    return None
out = []
for event, needle, label in [
    ("PreToolUse",  "block-dangerous-git.py", "safety:block-dangerous-git"),
    ("SessionStart","session-start.sh",       "safety:session-start"),
    ("PostToolUse", "auto-save.sh",           "auto-commit (full mode only)"),
]:
    cmd = has(event, needle)
    if cmd: out.append(f"OK:{event}:{label}:{cmd}")
    else:   out.append(f"MISS:{event}:{label}")
print("\n".join(out))
'@
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp.FullName -Value $py -Encoding UTF8
        $lines = & $Python $tmp.FullName $SettingsPrimary
        Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if ($line -like 'PARSE_ERROR:*') {
                MISS "settings.json could not be parsed: $($line.Substring(12))"
                $hooksUnparseable = 1
                AddStep "fix or restore settings.json from backup (.backup-*)"
            } elseif ($line -like 'OK:PreToolUse:*' -or $line -like 'OK:SessionStart:*') {
                OK $line.Substring(3)
                $safeHooksConfigured++
            } elseif ($line -like 'OK:*') {
                OK $line.Substring(3)
            } elseif ($line -like 'MISS:*') {
                WARN ($line.Substring(5) + " not configured")
            }
        }
    } else {
        WARN "skipped hook inspection (python missing)"
    }
} else {
    WARN "$SettingsPrimary missing (commands-only install does not create it)"
}

Section "[hook runtime verification]"
Write-Host "  'configured' (settings.json entry) is not 'verified' (file exists" -ForegroundColor DarkGray
Write-Host "  and runtime smoke passed). This section runs the latter." -ForegroundColor DarkGray

$hookRuntimeFail = 0
$blockHook    = Join-Path $ClaudeHome "hooks\block-dangerous-git.py"
$sessionHook  = Join-Path $ClaudeHome "hooks\session-start.sh"

if (Test-Path -LiteralPath $blockHook) {
    OK "block-dangerous-git.py present"
    if ($Python) {
        & $Python -m py_compile $blockHook 2>$null
        if ($LASTEXITCODE -eq 0) {
            OK "block-dangerous-git.py compiles"
        } else {
            MISS "block-dangerous-git.py does NOT compile under $Python"
            $hookRuntimeFail++
            AddStep "investigate $blockHook (py_compile failed); reinstall: .\install.ps1 -Mode safe"
        }
        function Smoke-One($payload, $expected, $label) {
            $env:VIBEKIT_HOOK_TEST_BRANCH = "feature/doctor-smoke"
            try {
                $payload | & $Python $blockHook 2>$null | Out-Null
                $actual = $LASTEXITCODE
            } finally {
                Remove-Item Env:\VIBEKIT_HOOK_TEST_BRANCH -ErrorAction SilentlyContinue
            }
            if ($actual -eq $expected) {
                OK "smoke: $label (exit $actual)"
            } else {
                MISS "smoke: $label expected exit $expected, got $actual"
                $script:hookRuntimeFail++
            }
        }
        Smoke-One '{"tool_input":{"command":"git status --short"}}'   0 "harmless git status allowed"
        Smoke-One '{"tool_input":{"command":"git push --force"}}'     2 "dangerous push blocked"
    } else {
        WARN "skipped block-dangerous-git.py compile/smoke (python missing)"
    }
} else {
    WARN "block-dangerous-git.py not installed (safe/full mode installs it)"
}

if (Test-Path -LiteralPath $sessionHook) {
    OK "session-start.sh present"
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    function Get-BashPathCandidates($Path) {
        $candidates = New-Object System.Collections.ArrayList
        [void]$candidates.Add($Path)
        if ($Path -match '^([A-Za-z]):\\(.*)$') {
            $drive = $matches[1].ToLower()
            $rest = $matches[2] -replace '\\','/'
            [void]$candidates.Add("/$drive/$rest")
            [void]$candidates.Add("/mnt/$drive/$rest")
        }
        return $candidates
    }
    function Test-BashSyntax($Path) {
        foreach ($candidate in (Get-BashPathCandidates $Path)) {
            & bash -n $candidate 2>$null
            if ($LASTEXITCODE -eq 0) { return $true }
        }
        return $false
    }
    if ($bashCmd) {
        if (Test-BashSyntax $sessionHook) {
            OK "session-start.sh syntax ok"
        } else {
            MISS "session-start.sh bash -n failed"
            $hookRuntimeFail++
        }
    } else {
        WARN "bash not available; cannot syntax-check session-start.sh (warning only)"
    }
}

if ((Test-Path -LiteralPath $SettingsPrimary) -and $Python) {
    $pyPath = @'
import json, os, shlex, shutil, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"PARSE_ERROR:{e}")
    sys.exit(0)
hooks = (data.get("hooks") or {})
issues = []
checked = 0
for event, entries in hooks.items():
    for entry in (entries or []):
        for h in (entry.get("hooks") or []):
            cmd = h.get("command", "")
            try:
                parts = shlex.split(cmd, posix=True)
            except ValueError:
                issues.append(f"{event}: could not parse command: {cmd}")
                continue
            if not parts: continue
            path = parts[0]
            checked += 1
            if not (os.path.exists(path) or shutil.which(path)):
                issues.append(f"{event}: {cmd} -> runtime missing: {path}")
            hook_path = next(
                (
                    p for p in parts[1:]
                    if "/hooks/" in p.replace("\\", "/")
                ),
                None,
            )
            if hook_path and not os.path.isfile(hook_path):
                issues.append(f"{event}: {cmd} -> hook file missing: {hook_path}")
print(f"CHECKED:{checked}")
for i in issues:
    print(f"ISSUE:{i}")
'@
    $tmpP = New-TemporaryFile
    Set-Content -Path $tmpP.FullName -Value $pyPath -Encoding UTF8
    try {
        $lines = & $Python $tmpP.FullName $SettingsPrimary
        foreach ($line in $lines) {
            if ($line -like 'CHECKED:*') {
                $n = [int]$line.Substring(8)
                if ($n -gt 0) { OK "settings hook command paths resolved ($n entry/entries)" }
            } elseif ($line -like 'ISSUE:*') {
                MISS $line.Substring(6)
                $hookRuntimeFail++
                AddStep "settings.json references a missing hook file - reinstall: .\install.ps1 -Mode safe"
            }
        }
    } finally {
        Remove-Item $tmpP.FullName -Force -ErrorAction SilentlyContinue
    }
}

if ($hookRuntimeFail -gt 0) {
    $requiredMissing += $hookRuntimeFail
    AddStep "$hookRuntimeFail hook runtime issue(s); rerun .\install.ps1 -Mode safe or check Windows Defender / antivirus"
}

Section "[optional integrations]"
if (Get-Command codex -ErrorAction SilentlyContinue) {
    $cv = (& codex --version 2>$null | Select-Object -First 1)
    OK "codex ($cv)"
} else {
    WARN "codex: not detected"
    $optionalMissing++
    AddStep "codex (optional): npm install -g @openai/codex"
}

if (Get-Command npx -ErrorAction SilentlyContinue) {
    & npx --yes bmad-method --version 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        OK "bmad-method available via npx"
    } else {
        WARN "bmad-method: not preinstalled (project-local; installs on first use)"
        $optionalMissing++
        AddStep "BMAD (project-local): cd <your project>; npx bmad-method install"
    }
} else {
    WARN "npx: not available; BMAD requires Node.js"
    $optionalMissing++
    AddStep "install Node.js >= 20 to enable BMAD via npx"
}

# gstack: look in multiple locations.
$gstackCandidates = @(
    (Join-Path $ClaudeHome "skills\gstack"),
    (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".claude\skills\gstack"),
    (Join-Path (Get-Location).Path ".claude\skills\gstack"),
    (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex\skills\gstack")
)
$gstackFound = $null
foreach ($c in $gstackCandidates) { if (Test-Path $c) { $gstackFound = $c; break } }
if ($gstackFound) {
    OK "gstack: $gstackFound"
} else {
    WARN "gstack: not detected by doctor"
    $optionalMissing++
    AddStep ("gstack (optional): git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git " + (Join-Path $ClaudeHome 'skills\gstack'))
}

# Plugin detection: multi-location, multi-source heuristic.
function Detect-Plugin($needle) {
    $settingsFiles = @(
        (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".claude\settings.json"),
        (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".claude\settings.local.json"),
        (Join-Path (Get-Location).Path ".claude\settings.json"),
        (Join-Path (Get-Location).Path ".claude\settings.local.json"),
        (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex\settings.json")
    )
    foreach ($f in $settingsFiles) {
        if (Test-Path $f) {
            $t = Get-Content $f -Raw -ErrorAction SilentlyContinue
            if ($t -and $t -match [Regex]::Escape($needle)) { return "settings:$f" }
        }
    }
    $dirs = @(
        (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".claude\plugins"),
        (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".claude\skills"),
        (Join-Path (Get-Location).Path ".claude\plugins"),
        (Join-Path (Get-Location).Path ".claude\skills"),
        (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex\plugins"),
        (Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex\skills")
    )
    foreach ($d in $dirs) {
        if (Test-Path $d) {
            $hit = Get-ChildItem -Path $d -Recurse -Depth 3 -Force -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -like "*$needle*" } | Select-Object -First 1
            if ($hit) { return "dir:$($hit.FullName)" }
        }
    }
    return $null
}

$sp = Detect-Plugin 'superpowers'
if ($sp) {
    OK "superpowers: detected by doctor heuristic ($sp)"
} else {
    WARN "superpowers: not detected by doctor (heuristic)"
    $optionalMissing++
    AddStep "superpowers (optional): /plugin marketplace add obra/superpowers-marketplace then /plugin install superpowers@superpowers-marketplace"
}

$ce = Detect-Plugin 'compound-engineering'
if ($ce) {
    OK "compound-engineering: detected by doctor heuristic ($ce)"
} else {
    WARN "compound-engineering: not detected by doctor (heuristic)"
    $optionalMissing++
    AddStep "compound-engineering (optional): install via Claude Code or Codex /plugins UI"
}

if ($Fix) {
    Section "[-Fix] Attempting safe automatic fixes"
    Write-Host "Only tools with clear CLI installation flows are auto-installed." -ForegroundColor DarkGray

    function Confirm-Fix($prompt) {
        if ($Yes) { return $true }
        $ans = Read-Host "  $prompt [y/N]"
        return ($ans -match '^(y|Y|yes|YES)$')
    }

    $fxAuto   = New-Object System.Collections.ArrayList
    $fxSkip   = New-Object System.Collections.ArrayList
    $fxManual = New-Object System.Collections.ArrayList
    $fxFail   = New-Object System.Collections.ArrayList

    function Invoke-GitCloneWithTimeout($destination, $timeoutSeconds = 120) {
        $args = @('clone', '--single-branch', '--depth', '1', 'https://github.com/garrytan/gstack.git', $destination)
        $proc = Start-Process -FilePath 'git' -ArgumentList $args -NoNewWindow -PassThru
        if (-not $proc.WaitForExit($timeoutSeconds * 1000)) {
            try { $proc.Kill() } catch {}
            return 124
        }
        return $proc.ExitCode
    }

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

    Section "[-Fix] Report"
    if ($fxAuto.Count   -gt 0) { Write-Host "  installed:" -ForegroundColor Green;     $fxAuto   | ForEach-Object { Write-Host "    - $_" } }
    if ($fxSkip.Count   -gt 0) { Write-Host "  skipped:"   -ForegroundColor DarkGray;  $fxSkip   | ForEach-Object { Write-Host "    - $_" } }
    if ($fxManual.Count -gt 0) { Write-Host "  manual:"    -ForegroundColor Yellow;    $fxManual | ForEach-Object { Write-Host "    - $_" } }
    if ($fxFail.Count   -gt 0) { Write-Host "  failures:"  -ForegroundColor Red;       $fxFail   | ForEach-Object { Write-Host "    - $_" } }
    Write-Host "Re-run doctor.ps1 (without -Fix) to see updated status." -ForegroundColor DarkGray
}

if ($NextSteps.Count -gt 0) {
    Section "[recommended next steps]"
    foreach ($s in $NextSteps) { Write-Host "  - $s" }
}

Write-Host ""
if ($requiredMissing -gt 0 -or $vibekitMissing -gt 0 -or $hooksUnparseable -eq 1) {
    Write-Host "ACTION REQUIRED" -ForegroundColor Red
    exit 2
} elseif ($optionalMissing -gt 0 -or $safeHooksConfigured -lt 2) {
    Write-Host "PARTIAL" -ForegroundColor Yellow
    Write-Host "Core commands installed; some optional integrations or safe-mode hooks" -ForegroundColor DarkGray
    Write-Host "are not configured. Audit-only flows are still usable." -ForegroundColor DarkGray
    exit 1
} else {
    Write-Host "READY" -ForegroundColor Green
    exit 0
}
