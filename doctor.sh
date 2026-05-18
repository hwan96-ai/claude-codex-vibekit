#!/usr/bin/env bash
# Claude-Codex Vibekit Doctor (macOS / Linux / WSL)
# Reports whether required and optional dependencies, Vibekit files, and hook
# settings are in place. Exit codes:
#   0 = READY
#   1 = PARTIAL
#   2 = ACTION REQUIRED

set -u

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

if [ -n "${CLAUDE_HOME+x}" ]; then
  CLAUDE_HOME_WAS_SET=1
else
  CLAUDE_HOME_WAS_SET=0
fi
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DEFAULT_CLAUDE_HOME="$HOME/.claude"

FIX=0
FIX_YES=0
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    --yes|-y) FIX_YES=1 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--fix] [--yes]

  --fix    Attempt safe automatic install for missing deps with clear CLI
           install flows (gstack). Prints guidance for the rest.
  --yes    Non-interactive (auto-confirm prompts in --fix mode).
EOF
      exit 0
      ;;
  esac
done

required_missing=0
optional_missing=0
vibekit_missing=0

ok()   { echo -e "  ${GREEN}ok ${NC} $*"; }
warn() { echo -e "  ${YELLOW}--${NC} $*"; }
miss() { echo -e "  ${RED}!! ${NC} $*"; }
info() { echo -e "  ${GRAY}.. ${NC} $*"; }

echo -e "${CYAN}=== Vibekit doctor ===${NC}"
echo "claude_home: $CLAUDE_HOME"
if [ "$CLAUDE_HOME_WAS_SET" -eq 0 ] && grep -qi microsoft /proc/version 2>/dev/null; then
  win_home=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
  if [ -n "$win_home" ]; then
    win_claude_home=$(wslpath -u "$win_home/.claude" 2>/dev/null || true)
    if [ -n "$win_claude_home" ] && [ "$win_claude_home" != "$DEFAULT_CLAUDE_HOME" ] && [ -d "$win_claude_home" ]; then
      warn "WSL detected: this checks Linux CLAUDE_HOME. Windows Claude home also exists at $win_claude_home"
      info "Use CLAUDE_HOME=$win_claude_home ./doctor.sh or run .\\doctor.ps1 in PowerShell to inspect the Windows install."
    fi
  fi
fi

echo -e "\n[required tools]"
for bin in git node bash; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin ($($bin --version 2>&1 | head -n1))"
  else
    miss "$bin: not found"
    required_missing=$((required_missing+1))
  fi
done

PYTHON_BIN=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1; then PYTHON_BIN="$cand"; break; fi
done
if [ -n "$PYTHON_BIN" ]; then
  ok "$PYTHON_BIN ($($PYTHON_BIN --version 2>&1))"
else
  miss "python / python3: not found"
  required_missing=$((required_missing+1))
fi

# Node version >= 20
if command -v node >/dev/null 2>&1; then
  nv=$(node -v 2>/dev/null | sed 's/^v//')
  major=${nv%%.*}
  if [ -n "${major:-}" ] && [ "$major" -ge 20 ] 2>/dev/null; then
    ok "node version >= 20 ($nv)"
  else
    miss "node version is $nv; >= 20 required"
    required_missing=$((required_missing+1))
  fi
fi

if command -v claude >/dev/null 2>&1; then
  ok "claude CLI found"
else
  miss "claude CLI: not found"
  echo "       install: curl -fsSL https://claude.ai/install.sh | bash"
  required_missing=$((required_missing+1))
fi

echo -e "\n[optional tools]"
if command -v codex >/dev/null 2>&1; then
  ok "codex ($(codex --version 2>/dev/null | head -n1))"
else
  warn "codex: not installed"
  echo "       install: npm install -g @openai/codex"
  optional_missing=$((optional_missing+1))
fi

if command -v npx >/dev/null 2>&1; then
  if npx --yes bmad-method --version >/dev/null 2>&1; then
    ok "bmad-method available via npx"
  else
    warn "bmad-method: not preinstalled (will install on first use)"
    echo "       to preinstall: npx bmad-method install"
    optional_missing=$((optional_missing+1))
  fi
else
  warn "npx: not available; BMAD requires Node.js"
  optional_missing=$((optional_missing+1))
fi

if [ -d "$CLAUDE_HOME/skills/gstack" ]; then
  ok "gstack: $CLAUDE_HOME/skills/gstack"
else
  warn "gstack: not installed"
  echo "       git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git $CLAUDE_HOME/skills/gstack"
  echo "       cd $CLAUDE_HOME/skills/gstack && ./setup"
  optional_missing=$((optional_missing+1))
fi

# Heuristic plugin detection (Claude Code stores plugin state in settings)
if [ -f "$CLAUDE_HOME/settings.json" ] && grep -q 'superpowers' "$CLAUDE_HOME/settings.json" 2>/dev/null; then
  ok "superpowers: referenced in settings.json"
else
  warn "superpowers: not detected"
  echo "       install via Claude Code /plugins UI"
  optional_missing=$((optional_missing+1))
fi
if [ -f "$CLAUDE_HOME/settings.json" ] && grep -q 'compound-engineering' "$CLAUDE_HOME/settings.json" 2>/dev/null; then
  ok "compound-engineering: referenced in settings.json"
else
  warn "compound-engineering: not detected"
  echo "       install via Claude Code /plugins UI (or Codex /plugins)"
  optional_missing=$((optional_missing+1))
fi

echo -e "\n[vibekit files]"
for f in \
  "$CLAUDE_HOME/commands/hwan-refactor-idea.md" \
  "$CLAUDE_HOME/commands/hwan-refactor-code.md" \
  "$CLAUDE_HOME/commands/hwan-refactor-design.md" \
  "$CLAUDE_HOME/commands/hwan-refactor-git.md" \
  "$CLAUDE_HOME/commands/git-safe.md"; do
  if [ -f "$f" ]; then ok "$f"; else miss "$f missing"; vibekit_missing=$((vibekit_missing+1)); fi
done

for f in \
  "$CLAUDE_HOME/hooks/block-dangerous-git.py" \
  "$CLAUDE_HOME/hooks/auto-save.sh" \
  "$CLAUDE_HOME/hooks/session-start.sh"; do
  if [ -f "$f" ]; then ok "$f"; else warn "$f not installed (safe/full mode would install it)"; fi
done

if [ -f "$CLAUDE_HOME/settings.json" ]; then
  ok "$CLAUDE_HOME/settings.json present"
else
  warn "$CLAUDE_HOME/settings.json missing (commands-only mode is fine without it)"
fi

echo -e "\n[settings.json hook entries]"
if [ -f "$CLAUDE_HOME/settings.json" ] && [ -n "$PYTHON_BIN" ]; then
  "$PYTHON_BIN" - "$CLAUDE_HOME/settings.json" <<'PYEOF'
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
            if contains in cmd:
                return cmd
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
    if cmd and command_runtime_available(cmd):
        print(f"  ok  {event}: {label} -> {cmd}")
    elif cmd:
        print(f"  !! {event}: {label} runtime not found -> {cmd}")
        missing_runtime = True
    else:
        print(f"  -- {event}: {label} not configured")
sys.exit(3 if missing_runtime else 0)
PYEOF
  if [ "$?" -ne 0 ]; then
    required_missing=$((required_missing+1))
  fi
else
  warn "skipped (no settings.json or no python)"
fi

if [ "$FIX" -eq 1 ]; then
  echo -e "\n${CYAN}[--fix] Attempting safe automatic fixes${NC}"
  echo -e "${GRAY}Only tools with clear CLI installation flows are auto-installed.${NC}"

  fix_confirm() {
    if [ "$FIX_YES" -eq 1 ]; then return 0; fi
    printf "  %s [y/N] " "$1"
    read -r _a
    case "$_a" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
  }

  clone_with_timeout() {
    # $1 = destination directory
    if command -v timeout >/dev/null 2>&1; then
      timeout 120 git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$1"
    else
      git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$1"
    fi
  }

  fix_auto=()
  fix_skip=()
  fix_manual=()
  fix_fail=()

  gstack_dir="$CLAUDE_HOME/skills/gstack"
  if [ -d "$gstack_dir" ]; then
    fix_skip+=("gstack (already installed)")
  elif ! command -v git >/dev/null 2>&1; then
    fix_fail+=("gstack: git missing")
  elif fix_confirm "Clone gstack into $gstack_dir and run setup?"; then
    mkdir -p "$CLAUDE_HOME/skills"
    if clone_with_timeout "$gstack_dir"; then
      if [ -f "$gstack_dir/setup" ]; then
        ( cd "$gstack_dir" && bash ./setup ) && fix_auto+=("gstack") \
          || fix_fail+=("gstack setup: cd $gstack_dir && ./setup")
      else
        fix_manual+=("gstack: cd $gstack_dir && ./setup (no setup script auto-detected)")
      fi
    else
      fix_fail+=("gstack clone timed out or failed: git clone https://github.com/garrytan/gstack.git $gstack_dir")
    fi
  else
    fix_skip+=("gstack (declined)")
  fi

  fix_manual+=("BMAD: run 'npx bmad-method install' inside your target project")
  fix_manual+=("superpowers: /plugin marketplace add obra/superpowers-marketplace && /plugin install superpowers@superpowers-marketplace")
  fix_manual+=("compound-engineering: install via Claude Code or Codex /plugins TUI")
  if ! command -v codex >/dev/null 2>&1; then
    fix_manual+=("codex (optional): npm install -g @openai/codex")
  fi

  echo -e "\n${CYAN}[--fix] Report${NC}"
  if [ ${#fix_auto[@]} -gt 0 ]; then
    echo -e "  ${GREEN}installed:${NC}";  for x in "${fix_auto[@]}";   do echo "    - $x"; done
  fi
  if [ ${#fix_skip[@]} -gt 0 ]; then
    echo -e "  ${GRAY}skipped:${NC}";    for x in "${fix_skip[@]}";   do echo "    - $x"; done
  fi
  if [ ${#fix_manual[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}manual:${NC}";   for x in "${fix_manual[@]}"; do echo "    - $x"; done
  fi
  if [ ${#fix_fail[@]} -gt 0 ]; then
    echo -e "  ${RED}failures:${NC}";    for x in "${fix_fail[@]}";   do echo "    - $x"; done
  fi
  echo -e "${GRAY}Re-run doctor.sh (without --fix) to see updated status.${NC}"
fi

echo ""
if [ "$required_missing" -gt 0 ] || [ "$vibekit_missing" -gt 0 ]; then
  echo -e "${RED}ACTION REQUIRED${NC}"
  exit 2
elif [ "$optional_missing" -gt 0 ]; then
  echo -e "${YELLOW}PARTIAL${NC}"
  exit 1
else
  echo -e "${GREEN}READY${NC}"
  exit 0
fi
