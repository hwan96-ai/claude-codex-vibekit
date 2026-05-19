# Claude-Codex Vibekit uninstaller (Windows PowerShell)
#
# Removes vibekit slash commands, hook scripts, and the hook entries the
# installer added to settings.json. Backs up settings.json first. Other keys
# are preserved.

[CmdletBinding()]
param(
    [switch]$Yes,
    [ValidateSet('global','project')]
    [string]$Scope = 'global',
    [string]$ClaudeHome
)

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
    $Settings = Join-Path $ClaudeHome "settings.local.json"
} else {
    $Settings = Join-Path $ClaudeHome "settings.json"
}

if ($env:CODEX_HOME) {
    $CodexHome = $env:CODEX_HOME
} else {
    $CodexHome = Join-Path ([Environment]::GetFolderPath("UserProfile")) ".codex"
}

Write-Host "Vibekit uninstall plan:"
Write-Host "  scope:       $Scope"
Write-Host "  claude_home: $ClaudeHome"
Write-Host "  codex_home:  $CodexHome"
Write-Host "  settings:    $Settings"
Write-Host "  - remove commands\hwan-refactor-*.md and commands\git-safe.md"
Write-Host "  - remove $CodexHome\prompts\hwan-refactor-*.md"
Write-Host "  - remove hooks\block-dangerous-git.py, hooks\auto-save.sh, hooks\session-start.sh"
Write-Host "  - remove vibekit-added entries from settings.json (backed up first)"
Write-Host "  - learnings\ are preserved (delete manually if desired)"

if (-not $Yes) {
    $ans = Read-Host "Proceed? [y/N]"
    if ($ans -notin @('y','Y','yes','YES')) { Write-Host "aborted"; exit 1 }
}

$targets = @(
    "commands\hwan-refactor-idea.md",
    "commands\hwan-refactor-code.md",
    "commands\hwan-refactor-design.md",
    "commands\hwan-refactor-git.md",
    "commands\git-safe.md",
    "hooks\block-dangerous-git.py",
    "hooks\auto-save.sh",
    "hooks\auto-save-payload.py",
    "hooks\session-start.sh"
)
$codexTargets = @(
    "prompts\hwan-refactor-idea.md",
    "prompts\hwan-refactor-code.md",
    "prompts\hwan-refactor-design.md",
    "prompts\hwan-refactor-git.md"
)
$removed = 0
foreach ($rel in $targets) {
    $p = Join-Path $ClaudeHome $rel
    if (Test-Path $p) {
        Remove-Item $p -Force
        Write-Host "removed $p"
        $removed++
    }
}
foreach ($rel in $codexTargets) {
    $p = Join-Path $CodexHome $rel
    if (Test-Path $p) {
        Remove-Item $p -Force
        Write-Host "removed $p"
        $removed++
    }
}

if (Test-Path $Settings) {
    $Python = $null
    foreach ($cand in @('python','python3','py')) {
        $c = Get-Command $cand -ErrorAction SilentlyContinue
        if ($c) { $Python = $c.Source; break }
    }
    if (-not $Python) {
        Write-Host "warning: python not found; settings.json not cleaned. Edit manually." -ForegroundColor Yellow
    } else {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item $Settings "$Settings.backup-$stamp" -Force
        $py = @'
import json, sys

p = sys.argv[1]
try:
    with open(p, "r", encoding="utf-8") as f: data = json.load(f)
except Exception as e:
    print(f"could not parse settings.json: {e}"); sys.exit(0)

# Vibekit's installer writes hook commands as `<runtime> <CLAUDE_HOME>/hooks/<basename>`.
# Anchor the match to a `/hooks/<basename>` path segment so a basename only
# matches when it sits inside a `hooks/` directory (forward- or backslash-
# separated), avoiding false positives like `/usr/local/bin/auto-save.sh`.
basenames = ("block-dangerous-git.py", "session-start.sh", "auto-save.sh")

def is_vibekit_command(cmd):
    if not cmd:
        return False
    return any(
        f"/hooks/{b}" in cmd or f"\\hooks\\{b}" in cmd
        for b in basenames
    )

hooks = data.get("hooks") or {}
for event in list(hooks.keys()):
    entries = hooks.get(event) or []
    new_entries = []
    for entry in entries:
        inner = entry.get("hooks") or []
        kept = [h for h in inner if not is_vibekit_command(h.get("command"))]
        if kept:
            entry["hooks"] = kept
            new_entries.append(entry)
    if new_entries: hooks[event] = new_entries
    else: del hooks[event]
if not hooks and "hooks" in data: del data["hooks"]
elif "hooks" in data: data["hooks"] = hooks
with open(p, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2); f.write("\n")
print(f"cleaned vibekit hook entries from {p}")
'@
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp.FullName -Value $py -Encoding UTF8
        & $Python $tmp.FullName $Settings
        Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "done. $removed file(s) removed."
Write-Host "If you want to remove learnings: Remove-Item -Recurse '$ClaudeHome\learnings'"
