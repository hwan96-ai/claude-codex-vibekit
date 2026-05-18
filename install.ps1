# Claude-Codex Vibekit Installer (Windows PowerShell)
#
# Usage:
#   .\install.ps1 -Mode safe           (recommended)
#   .\install.ps1 -Mode commands-only  (safest; no hooks, no settings changes)
#   .\install.ps1 -Mode full           (adds auto-save / auto-commit hook)
#
# The installer is idempotent. Running it again will not duplicate hook entries.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('commands-only','safe','full')]
    [string]$Mode,

    [ValidateSet('global','project')]
    [string]$Scope = 'global',

    [string]$ClaudeHome,

    [switch]$InstallClaude,

    [switch]$Bootstrap,
    [switch]$Yes,
    [switch]$BootstrapCodex
)

$ErrorActionPreference = "Stop"

function Write-Info($msg)  { Write-Host $msg -ForegroundColor Cyan }
function Write-OK($msg)    { Write-Host $msg -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Gray($msg)  { Write-Host $msg -ForegroundColor DarkGray }
function Write-Err($msg)   { Write-Host $msg -ForegroundColor Red }

# Path detection. Precedence: -ClaudeHome > -Scope project > $env:CLAUDE_HOME > $HOME\.claude.
$UserHome = [Environment]::GetFolderPath("UserProfile")
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Cwd      = (Get-Location).Path

if ($ClaudeHome) {
    # explicit path wins
} elseif ($Scope -eq 'project') {
    $ClaudeHome = Join-Path $Cwd ".claude"
} elseif ($env:CLAUDE_HOME) {
    $ClaudeHome = $env:CLAUDE_HOME
} else {
    $ClaudeHome = Join-Path $UserHome ".claude"
}

Write-Info "`n=== Claude-Codex Vibekit Installer (mode: $Mode, scope: $Scope) ==="
Write-Gray "  home:        $UserHome"
Write-Gray "  claude_home: $ClaudeHome"
Write-Gray "  repo_root:   $RepoRoot"
Write-Gray "  cwd:         $Cwd"

# Project-scope safety: warn if installing into the vibekit repo itself.
if ($Scope -eq 'project' -and ($Cwd.TrimEnd('\','/').ToLower() -eq $RepoRoot.TrimEnd('\','/').ToLower())) {
    Write-Warn2 "warning: project-scope install inside the Vibekit repo will modify"
    Write-Warn2 "         $RepoRoot\.claude (the kit's own source directory)."
    if (-not $Yes) {
        $ans = Read-Host "Continue? [y/N]"
        if ($ans -notmatch '^(y|Y|yes|YES)$') { Write-Host "aborted"; exit 1 }
    }
}

# Detect Python (needed for safe JSON merging)
$PythonBin = $null
foreach ($cand in @('python','python3','py')) {
    $c = Get-Command $cand -ErrorAction SilentlyContinue
    if ($c) { $PythonBin = $c.Source; break }
}

# ---------- 1. Directories ----------
Write-Host "`n[1] Ensuring directories exist..."
$dirs = @('commands','hooks','learnings\idea','learnings\code','learnings\design','learnings\git')
foreach ($d in $dirs) {
    $full = Join-Path $ClaudeHome $d
    if (-not (Test-Path $full)) {
        New-Item -ItemType Directory -Path $full -Force | Out-Null
        Write-OK "  created $full"
    } else {
        Write-Gray "  exists  $full"
    }
}

# ---------- 2. Slash commands ----------
Write-Host "`n[2] Installing slash commands..."
$cmdSrcDir = Join-Path $RepoRoot ".claude\commands"
$cmdDstDir = Join-Path $ClaudeHome "commands"
function Test-SamePath($a, $b) {
    try {
        $ra = (Resolve-Path -LiteralPath $a -ErrorAction Stop).Path
        $rb = (Resolve-Path -LiteralPath $b -ErrorAction Stop).Path
        return ($ra.ToLower() -eq $rb.ToLower())
    } catch { return $false }
}
Get-ChildItem -Path $cmdSrcDir -Filter "*.md" | ForEach-Object {
    $dst = Join-Path $cmdDstDir $_.Name
    if (Test-SamePath $_.FullName $dst) {
        Write-Gray "  skip   $dst (same file)"
    } else {
        Copy-Item $_.FullName $dst -Force
        Write-OK "  copied $dst"
    }
}

if ($Mode -eq 'commands-only') {
    Write-Host "`n[3] Mode is commands-only: skipping hooks and settings.json."
    Write-Info "`n=== Done ==="
    Write-Host "Next:"
    Write-Host "  - Run .\doctor.ps1 to verify."
    Write-Host "  - Open Claude Code and try /hwan-refactor-idea --audit-only on a test project."
    exit 0
}

# ---------- 3. Hooks ----------
Write-Host "`n[3] Installing hook scripts into $ClaudeHome\hooks ..."
$hookSrcDir = Join-Path $RepoRoot ".claude\hooks"
$hookDstDir = Join-Path $ClaudeHome "hooks"
Get-ChildItem -Path $hookSrcDir -File | ForEach-Object {
    $dst = Join-Path $hookDstDir $_.Name
    if (Test-SamePath $_.FullName $dst) {
        Write-Gray "  skip   $dst (same file)"
    } else {
        Copy-Item $_.FullName $dst -Force
        Write-OK "  copied $dst"
    }
}

# ---------- 4. settings.json merge ----------
if ($Scope -eq 'project') {
    $Settings = Join-Path $ClaudeHome "settings.local.json"
} else {
    $Settings = Join-Path $ClaudeHome "settings.json"
}
Write-Host "`n[4] Merging $Settings (mode: $Mode)..."

if (-not $PythonBin) {
    Write-Err "  error: python is required to merge settings.json safely. Install Python 3."
    Write-Warn2 "  Hooks were copied, but settings.json was NOT modified."
    exit 1
}

if (Test-Path $Settings) {
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$Settings.backup-$stamp"
    Copy-Item $Settings $backup -Force
    Write-OK "  backup $backup"
}

$enableAutosave = '0'
if ($Mode -eq 'full') {
    $enableAutosave = '1'
    Write-Host ""
    Write-Warn2 "FULL mode enables auto-save / auto-commit behavior."
    Write-Warn2 'After file edits, a hook runs:  git add -A && git commit -m "autosave: ..."'
    Write-Warn2 "This stages the entire working tree, including unrelated changes,"
    Write-Warn2 "and refuses to commit on main/master. Use only if you want this."
    Write-Host ""
}

$pyScript = @'
import json, os, sys

settings_path = sys.argv[1]
claude_home   = sys.argv[2]
enable_autosave = sys.argv[3] == "1"
claude_home_fwd = claude_home.replace("\\", "/")

data = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"  error: existing settings.json is not valid JSON: {e}", file=sys.stderr)
        print(f"  refused to overwrite. backup is at {settings_path}.backup-*", file=sys.stderr)
        sys.exit(1)

if not isinstance(data, dict):
    print("  error: settings.json root is not an object; refusing to modify.", file=sys.stderr)
    sys.exit(1)

hooks = data.setdefault("hooks", {})

def ensure_hook(event, matcher, command):
    entries = hooks.setdefault(event, [])
    for entry in entries:
        if entry.get("matcher", "") == matcher:
            inner = entry.setdefault("hooks", [])
            for h in inner:
                if h.get("type") == "command" and h.get("command") == command:
                    return False
            inner.append({"type": "command", "command": command})
            return True
    entries.append({"matcher": matcher, "hooks": [{"type": "command", "command": command}]})
    return True

added = []
if ensure_hook("PreToolUse", "Bash", f"python {claude_home_fwd}/hooks/block-dangerous-git.py"):
    added.append("PreToolUse:Bash -> block-dangerous-git.py")
if ensure_hook("SessionStart", "", f"bash {claude_home_fwd}/hooks/session-start.sh"):
    added.append("SessionStart -> session-start.sh")

if enable_autosave:
    if ensure_hook("PostToolUse", "Edit|Write|MultiEdit", f"bash {claude_home_fwd}/hooks/auto-save.sh"):
        added.append("PostToolUse:Edit|Write|MultiEdit -> auto-save.sh")

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

if added:
    for line in added:
        print(f"  added  {line}")
else:
    print("  no changes needed (hooks already present)")
'@

$tmpPy = New-TemporaryFile
try {
    Set-Content -Path $tmpPy.FullName -Value $pyScript -Encoding UTF8
    & $PythonBin $tmpPy.FullName $Settings $ClaudeHome $enableAutosave
    if ($LASTEXITCODE -ne 0) {
        Write-Err "  settings.json merge failed; existing file was preserved (backup above)."
        exit 1
    }
} finally {
    Remove-Item $tmpPy.FullName -Force -ErrorAction SilentlyContinue
}

# ---------- 5. Dependency report ----------
Write-Host "`n[5] Checking optional integrations (informational only)..."

if (Test-Path (Join-Path $ClaudeHome "skills\gstack")) {
    Write-OK ("  gstack:    installed at " + (Join-Path $ClaudeHome "skills\gstack"))
} else {
    Write-Warn2 "  gstack:    not installed (optional)"
    Write-Host "    To install (PowerShell):"
    Write-Host "      git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git `"$ClaudeHome\skills\gstack`""
    Write-Host "      cd `"$ClaudeHome\skills\gstack`"; .\setup"
}

if (Get-Command codex -ErrorAction SilentlyContinue) {
    $cv = (& codex --version 2>$null | Select-Object -First 1)
    Write-OK "  codex:     installed ($cv)"
} else {
    Write-Gray "  codex:     not installed (optional). Install: npm install -g @openai/codex"
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-OK "  claude:    installed"
} else {
    Write-Warn2 "  claude:    Claude Code CLI not found."
    Write-Host  "    Install (PowerShell): irm https://claude.ai/install.ps1 | iex"
}

# ---------- 6. Bootstrap (opt-in) ----------
if ($Bootstrap) {
    Write-Info "`n[6] Bootstrap (opt-in)"
    $bsAuto = New-Object System.Collections.ArrayList
    $bsSkip = New-Object System.Collections.ArrayList
    $bsManual = New-Object System.Collections.ArrayList
    $bsFail = New-Object System.Collections.ArrayList

    function Confirm-Bootstrap($prompt) {
        if ($Yes) { return $true }
        $ans = Read-Host "  $prompt [y/N]"
        return ($ans -match '^(y|Y|yes|YES)$')
    }

    # gstack
    $gstackDir = Join-Path $ClaudeHome "skills\gstack"
    if (Test-Path $gstackDir) {
        Write-OK "  gstack: already installed at $gstackDir"
        [void]$bsSkip.Add("gstack (already installed)")
    } elseif (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Err "  gstack: git not found; cannot clone"
        [void]$bsFail.Add("gstack: install git first")
    } elseif (Confirm-Bootstrap "Clone gstack into $gstackDir and run setup?") {
        New-Item -ItemType Directory -Path (Join-Path $ClaudeHome "skills") -Force | Out-Null
        & git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git $gstackDir
        if ($LASTEXITCODE -eq 0) {
            $setupPath = Join-Path $gstackDir "setup"
            if (Test-Path $setupPath) {
                Push-Location $gstackDir
                try {
                    # Prefer bash if available (gstack setup is typically a bash script).
                    $bash = Get-Command bash -ErrorAction SilentlyContinue
                    if ($bash) {
                        & bash ./setup
                    } else {
                        & $setupPath
                    }
                    if ($LASTEXITCODE -eq 0) {
                        [void]$bsAuto.Add("gstack")
                    } else {
                        [void]$bsFail.Add("gstack setup: cd $gstackDir; bash ./setup")
                    }
                } finally { Pop-Location }
            } else {
                Write-Warn2 "  gstack: ./setup not found; clone done, manual setup may be needed"
                [void]$bsManual.Add("gstack: cd $gstackDir; .\setup")
            }
        } else {
            [void]$bsFail.Add("gstack clone: git clone https://github.com/garrytan/gstack.git `"$gstackDir`"")
        }
    } else {
        [void]$bsSkip.Add("gstack (declined)")
    }

    # BMAD (project-local)
    Write-Gray "  BMAD is project-local. Run inside your TARGET project:"
    Write-Host "    npx bmad-method install"
    [void]$bsManual.Add("BMAD: run 'npx bmad-method install' inside your target project (NOT inside the Vibekit repo)")

    # Codex CLI
    if (Get-Command codex -ErrorAction SilentlyContinue) {
        [void]$bsSkip.Add("codex (already installed)")
    } elseif ($BootstrapCodex) {
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            [void]$bsFail.Add("codex: npm not found; install Node.js 20+ first")
        } elseif (Confirm-Bootstrap "Install codex globally via 'npm install -g @openai/codex'?") {
            & npm install -g @openai/codex
            if ($LASTEXITCODE -eq 0) { [void]$bsAuto.Add("codex") }
            else { [void]$bsFail.Add("codex: npm install -g @openai/codex") }
        } else {
            [void]$bsSkip.Add("codex (declined)")
        }
    } else {
        [void]$bsManual.Add("codex (optional): npm install -g @openai/codex  -- pass -BootstrapCodex to auto-install")
    }

    Write-Gray "  superpowers and compound-engineering must be installed via Claude Code plugins."
    Write-Host "    /plugin marketplace add obra/superpowers-marketplace"
    Write-Host "    /plugin install superpowers@superpowers-marketplace"
    Write-Host "    (compound-engineering: install via Claude Code or Codex /plugins TUI)"
    [void]$bsManual.Add("superpowers: /plugin marketplace add obra/superpowers-marketplace then /plugin install superpowers@superpowers-marketplace")
    [void]$bsManual.Add("compound-engineering: install via Claude Code or Codex /plugins TUI")

    Write-Info "`n[6] Bootstrap report"
    if ($bsAuto.Count -gt 0) {
        Write-OK "  installed automatically:"
        $bsAuto   | ForEach-Object { Write-Host "    - $_" }
    }
    if ($bsSkip.Count -gt 0) {
        Write-Gray "  skipped:"
        $bsSkip   | ForEach-Object { Write-Host "    - $_" }
    }
    if ($bsManual.Count -gt 0) {
        Write-Warn2 "  manual steps required:"
        $bsManual | ForEach-Object { Write-Host "    - $_" }
    }
    if ($bsFail.Count -gt 0) {
        Write-Err "  failures (recovery commands):"
        $bsFail   | ForEach-Object { Write-Host "    - $_" }
    }
}

Write-Info "`n=== Done (mode: $Mode) ==="
Write-Host "Next:"
Write-Host "  - Run .\doctor.ps1 to verify  (use -Fix to attempt safe automatic fixes)."
Write-Host "  - Restart Claude Code so it reloads commands and settings."
Write-Host "  - Try a gate in audit-only mode first: /hwan-refactor-idea --audit-only"
exit 0
