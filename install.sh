#!/usr/bin/env bash
# Claude-Codex Vibekit Installer (macOS / Linux / WSL)
#
# Usage:
#   ./install.sh --mode safe           (recommended default)
#   ./install.sh --mode commands-only  (safest; no hooks, no settings changes)
#   ./install.sh --mode full           (adds auto-save / auto-commit hook)
#
# The installer is idempotent. Running it again will not duplicate hook entries.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

MODE=""
INSTALL_CLAUDE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="${2:-}"; shift 2
      ;;
    --mode=*)
      MODE="${1#*=}"; shift
      ;;
    --install-claude)
      INSTALL_CLAUDE=1; shift
      ;;
    -h|--help)
      cat <<EOF
Claude-Codex Vibekit installer

Usage:
  $0 --mode <commands-only|safe|full>

Modes:
  commands-only  Copy slash commands only. No hooks. No settings.json changes.
  safe           commands-only + copy hooks + enable safety-only hooks
                 (block dangerous git, session-start branch safety).
                 Auto-save / auto-commit hook is NOT enabled.
  full           safe + enable auto-save / auto-commit hook. Power-user mode.

Flags:
  --install-claude   Reserved. Currently prints guidance only.
  -h, --help         Show this help.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$MODE" ]; then
  echo -e "${RED}error:${NC} --mode is required. Choose one of: commands-only, safe, full" >&2
  echo "Try: $0 --mode safe" >&2
  exit 2
fi

case "$MODE" in
  commands-only|safe|full) ;;
  *)
    echo -e "${RED}error:${NC} unknown mode '$MODE'. Use commands-only, safe, or full." >&2
    exit 2
    ;;
esac

echo -e "\n${CYAN}=== Claude-Codex Vibekit Installer (mode: $MODE) ===${NC}"

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "  ${GRAY}home:        $HOME${NC}"
echo -e "  ${GRAY}claude_home: $CLAUDE_HOME${NC}"
echo -e "  ${GRAY}repo_root:   $REPO_ROOT${NC}"

# Pick a python3 interpreter for JSON merging
PYTHON_BIN=""
for cand in python3 python; do
  if command -v "$cand" >/dev/null 2>&1; then
    PYTHON_BIN="$cand"; break
  fi
done

# ---------- 1. Directories ----------
echo -e "\n[1] Ensuring directories exist..."
for d in commands hooks learnings/idea learnings/code learnings/design learnings/git; do
  full="$CLAUDE_HOME/$d"
  if [ ! -d "$full" ]; then
    mkdir -p "$full"
    echo -e "  ${GREEN}created${NC} $full"
  else
    echo -e "  ${GRAY}exists ${NC} $full"
  fi
done

# ---------- 2. Slash commands ----------
echo -e "\n[2] Installing slash commands..."
for src in "$REPO_ROOT/.claude/commands/"*.md; do
  [ -f "$src" ] || continue
  base="$(basename "$src")"
  dst="$CLAUDE_HOME/commands/$base"
  cp -f "$src" "$dst"
  echo -e "  ${GREEN}copied${NC} $dst"
done

if [ "$MODE" = "commands-only" ]; then
  echo -e "\n[3] Mode is commands-only: skipping hooks and settings.json."
  echo -e "\n${CYAN}=== Done ===${NC}"
  echo -e "Next:"
  echo -e "  - Run ./doctor.sh to verify."
  echo -e "  - Open Claude Code and try /hwan-refactor-idea --audit-only on a test project."
  exit 0
fi

# ---------- 3. Hooks (safe + full) ----------
echo -e "\n[3] Installing hook scripts into $CLAUDE_HOME/hooks ..."
for src in "$REPO_ROOT/.claude/hooks/"*; do
  [ -f "$src" ] || continue
  base="$(basename "$src")"
  dst="$CLAUDE_HOME/hooks/$base"
  cp -f "$src" "$dst"
  case "$base" in
    *.sh|*.py) chmod +x "$dst" 2>/dev/null || true ;;
  esac
  echo -e "  ${GREEN}copied${NC} $dst"
done

# ---------- 4. settings.json merge ----------
echo -e "\n[4] Merging settings.json (mode: $MODE)..."
SETTINGS="$CLAUDE_HOME/settings.json"

if [ -z "$PYTHON_BIN" ]; then
  echo -e "  ${RED}error:${NC} python is required to merge settings.json safely. Install Python 3."
  echo -e "  ${YELLOW}Hooks were copied, but settings.json was NOT modified.${NC}"
  exit 1
fi

if [ -f "$SETTINGS" ]; then
  BACKUP="$SETTINGS.backup-$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  echo -e "  ${GREEN}backup${NC} $BACKUP"
fi

ENABLE_AUTOSAVE=0
if [ "$MODE" = "full" ]; then
  ENABLE_AUTOSAVE=1
  echo ""
  echo -e "${YELLOW}FULL mode enables auto-save / auto-commit behavior.${NC}"
  echo -e "${YELLOW}After file edits, a hook runs:  git add -A && git commit -m \"autosave: ...\"${NC}"
  echo -e "${YELLOW}This stages the entire working tree, including unrelated changes,${NC}"
  echo -e "${YELLOW}and refuses to commit on main/master. Use only if you want this.${NC}"
  echo ""
fi

"$PYTHON_BIN" - "$SETTINGS" "$CLAUDE_HOME" "$ENABLE_AUTOSAVE" <<'PYEOF'
import json, os, sys

settings_path, claude_home, enable_autosave = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
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
    """Ensure exactly one entry exists for (event, matcher, command). Idempotent."""
    entries = hooks.setdefault(event, [])
    target_cmd = command
    for entry in entries:
        if entry.get("matcher", "") == matcher:
            inner = entry.setdefault("hooks", [])
            for h in inner:
                if h.get("type") == "command" and h.get("command") == target_cmd:
                    return False  # already there
            inner.append({"type": "command", "command": target_cmd})
            return True
    entries.append({
        "matcher": matcher,
        "hooks": [{"type": "command", "command": target_cmd}],
    })
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
PYEOF

# ---------- 5. Dependency report ----------
echo -e "\n[5] Checking optional integrations (informational only)..."

if [ -d "$CLAUDE_HOME/skills/gstack" ]; then
  echo -e "  ${GREEN}gstack:${NC}    installed at $CLAUDE_HOME/skills/gstack"
else
  echo -e "  ${YELLOW}gstack:${NC}    not installed (optional)"
  echo -e "    To install:"
  echo -e "      git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git $CLAUDE_HOME/skills/gstack"
  echo -e "      cd $CLAUDE_HOME/skills/gstack && ./setup"
fi

if command -v codex >/dev/null 2>&1; then
  echo -e "  ${GREEN}codex:${NC}     installed ($(codex --version 2>/dev/null | head -n1))"
else
  echo -e "  ${GRAY}codex:${NC}     not installed (optional). Install: npm install -g @openai/codex"
fi

if command -v claude >/dev/null 2>&1; then
  echo -e "  ${GREEN}claude:${NC}    installed"
else
  echo -e "  ${YELLOW}claude:${NC}    Claude Code CLI not found."
  echo -e "    Install: curl -fsSL https://claude.ai/install.sh | bash"
fi

echo -e "\n${CYAN}=== Done (mode: $MODE) ===${NC}"
echo -e "Next:"
echo -e "  - Run ./doctor.sh to verify."
echo -e "  - Restart Claude Code so it reloads commands and settings."
echo -e "  - Try a gate in audit-only mode first: /hwan-refactor-idea --audit-only"
