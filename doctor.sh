#!/usr/bin/env bash
# Claude-Codex Vibekit Doctor (macOS / Linux / WSL)
#
# Sections (printed in order):
#   [core readiness]       required tools and Vibekit files
#   [hook configuration]   settings.json hook wiring
#   [optional integrations] codex, gstack, BMAD, plugins
#   [recommended next steps] one-line fix per missing item
#
# Verdicts:
#   READY            — required tools present, core commands installed,
#                      hooks configured if expected. Optional gaps allowed
#                      only in commands-only / mode=unknown installs.
#   PARTIAL          — core OK, but some optional integrations missing or
#                      safe hooks not configured (commands-only install).
#                      Audit-only command flows still usable.
#   ACTION REQUIRED  — required tool missing, core command files missing,
#                      unparseable settings.json, or installer did not finish.
#
# Exit codes: 0 READY, 1 PARTIAL, 2 ACTION REQUIRED.

set -u

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

FIX=0
FIX_YES=0
SCOPE="global"
CLAUDE_HOME_ARG=""
CI_MODE=0

for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    --yes|-y) FIX_YES=1 ;;
    --ci) CI_MODE=1 ;;
    --scope=project) SCOPE="project" ;;
    --scope=global)  SCOPE="global" ;;
    --claude-home=*) CLAUDE_HOME_ARG="${arg#*=}" ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--fix] [--yes] [--ci] [--scope global|project] [--claude-home=<path>]

  --fix             Attempt safe automatic install for missing deps with
                    clear CLI install flows (gstack).
  --yes             Non-interactive (auto-confirm prompts in --fix mode).
  --ci              CI smoke mode. Missing Claude CLI is downgraded to
                    PARTIAL instead of ACTION REQUIRED so CI runners that
                    don't have Claude Code installed can still validate the
                    installer + doctor wiring.
  --scope project   Inspect project-local ./.claude instead of global.
  --claude-home     Explicit Claude home directory.
EOF
      exit 0
      ;;
  esac
done

if [ -n "$CLAUDE_HOME_ARG" ]; then
  CLAUDE_HOME="$CLAUDE_HOME_ARG"
elif [ "$SCOPE" = "project" ]; then
  CLAUDE_HOME="$(pwd)/.claude"
else
  CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
fi

# Settings file convention: project scope prefers settings.local.json; global
# uses settings.json. Doctor still inspects both for hook wiring.
if [ "$SCOPE" = "project" ]; then
  SETTINGS_PRIMARY="$CLAUDE_HOME/settings.local.json"
else
  SETTINGS_PRIMARY="$CLAUDE_HOME/settings.json"
fi

required_missing=0
optional_missing=0
vibekit_missing=0
hooks_unparseable=0
NEXT_STEPS=()

ok()   { echo -e "  ${GREEN}ok ${NC} $*"; }
warn() { echo -e "  ${YELLOW}--${NC} $*"; }
miss() { echo -e "  ${RED}!! ${NC} $*"; }
info() { echo -e "  ${GRAY}.. ${NC} $*"; }
add_step() { NEXT_STEPS+=("$1"); }

echo -e "${CYAN}=== Vibekit doctor ===${NC}"
echo "scope:       $SCOPE"
echo "claude_home: $CLAUDE_HOME"
echo "settings:    $SETTINGS_PRIMARY"

# ---------- [core readiness] ----------
echo -e "\n${CYAN}[core readiness]${NC}"
for bin in git node; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin ($($bin --version 2>&1 | head -n1))"
  else
    miss "$bin: not found"
    required_missing=$((required_missing+1))
    add_step "install $bin (required)"
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
  add_step "install Python 3 (required for installer JSON merge + hooks)"
fi

if command -v node >/dev/null 2>&1; then
  nv=$(node -v 2>/dev/null | sed 's/^v//')
  major=${nv%%.*}
  if [ -n "${major:-}" ] && [ "$major" -ge 20 ] 2>/dev/null; then
    ok "node version >= 20 ($nv)"
  else
    miss "node version is $nv; >= 20 required"
    required_missing=$((required_missing+1))
    add_step "upgrade Node.js to >= 20"
  fi
fi

if command -v claude >/dev/null 2>&1; then
  ok "claude CLI found"
elif [ "$CI_MODE" -eq 1 ]; then
  warn "claude CLI not found (allowed in CI smoke mode)"
  optional_missing=$((optional_missing+1))
  add_step "install Claude Code (skipped in CI): curl -fsSL https://claude.ai/install.sh | bash"
else
  miss "claude CLI: not found"
  required_missing=$((required_missing+1))
  add_step "install Claude Code: curl -fsSL https://claude.ai/install.sh | bash"
fi

# Vibekit command files
for f in \
  "$CLAUDE_HOME/commands/hwan-refactor-idea.md" \
  "$CLAUDE_HOME/commands/hwan-refactor-code.md" \
  "$CLAUDE_HOME/commands/hwan-refactor-design.md" \
  "$CLAUDE_HOME/commands/hwan-refactor-git.md" \
  "$CLAUDE_HOME/commands/git-safe.md"; do
  if [ -f "$f" ]; then ok "$f"; else miss "$f missing"; vibekit_missing=$((vibekit_missing+1)); fi
done
if [ "$vibekit_missing" -gt 0 ]; then
  add_step "re-run installer: ./install.sh --mode commands-only [--scope $SCOPE]"
fi

# Hook scripts on disk (informational; only required for safe/full)
for f in \
  "$CLAUDE_HOME/hooks/block-dangerous-git.py" \
  "$CLAUDE_HOME/hooks/auto-save.sh" \
  "$CLAUDE_HOME/hooks/session-start.sh"; do
  if [ -f "$f" ]; then ok "$f"; else warn "$f not installed (safe/full mode installs it)"; fi
done

# ---------- [hook configuration] ----------
echo -e "\n${CYAN}[hook configuration]${NC}"
SAFE_HOOKS_CONFIGURED=0
if [ -f "$SETTINGS_PRIMARY" ]; then
  ok "$SETTINGS_PRIMARY present"
  if [ -n "$PYTHON_BIN" ]; then
    OUT=$("$PYTHON_BIN" - "$SETTINGS_PRIMARY" <<'PYEOF'
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
            if contains in cmd:
                return cmd
    return None
results = []
for event, needle, label in [
    ("PreToolUse",  "block-dangerous-git.py", "safety:block-dangerous-git"),
    ("SessionStart","session-start.sh",       "safety:session-start"),
    ("PostToolUse", "auto-save.sh",           "auto-commit (full mode only)"),
]:
    cmd = has(event, needle)
    if cmd: results.append(f"OK:{event}:{label}:{cmd}")
    else:   results.append(f"MISS:{event}:{label}")
print("\n".join(results))
PYEOF
)
    if echo "$OUT" | grep -q '^PARSE_ERROR:'; then
      miss "settings.json could not be parsed: ${OUT#PARSE_ERROR:}"
      hooks_unparseable=1
      add_step "fix or restore settings.json from backup (~/.claude/settings.json.backup-*)"
    else
      while IFS= read -r line; do
        case "$line" in
          OK:PreToolUse:*)   ok "${line#OK:}"; SAFE_HOOKS_CONFIGURED=$((SAFE_HOOKS_CONFIGURED+1)) ;;
          OK:SessionStart:*) ok "${line#OK:}"; SAFE_HOOKS_CONFIGURED=$((SAFE_HOOKS_CONFIGURED+1)) ;;
          OK:*)              ok "${line#OK:}" ;;
          MISS:*)            warn "${line#MISS:} not configured" ;;
        esac
      done <<< "$OUT"
    fi
  else
    warn "skipped hook inspection (python missing)"
  fi
else
  warn "$SETTINGS_PRIMARY missing (commands-only install does not create it)"
fi

# ---------- [optional integrations] ----------
echo -e "\n${CYAN}[optional integrations]${NC}"
if command -v codex >/dev/null 2>&1; then
  ok "codex ($(codex --version 2>/dev/null | head -n1))"
else
  warn "codex: not detected"
  optional_missing=$((optional_missing+1))
  add_step "codex (optional): npm install -g @openai/codex"
fi

if command -v npx >/dev/null 2>&1; then
  if npx --yes bmad-method --version >/dev/null 2>&1; then
    ok "bmad-method available via npx"
  else
    warn "bmad-method: not preinstalled (project-local; installs on first use)"
    optional_missing=$((optional_missing+1))
    add_step "BMAD (project-local): cd <your project>; npx bmad-method install"
  fi
else
  warn "npx: not available; BMAD requires Node.js"
  optional_missing=$((optional_missing+1))
  add_step "install Node.js >= 20 to enable BMAD via npx"
fi

# gstack: check global skills dir, optional project skills dir, and codex.
gstack_found=""
for cand in "$CLAUDE_HOME/skills/gstack" "$HOME/.claude/skills/gstack" "$(pwd)/.claude/skills/gstack" "$HOME/.codex/skills/gstack"; do
  if [ -d "$cand" ]; then gstack_found="$cand"; break; fi
done
if [ -n "$gstack_found" ]; then
  ok "gstack: $gstack_found"
else
  warn "gstack: not detected by doctor"
  optional_missing=$((optional_missing+1))
  add_step "gstack (optional): git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git $CLAUDE_HOME/skills/gstack && (cd $_; ./setup)"
fi

# Plugin detection: inspect multiple settings + plugin/skill directories,
# both global and project, and ~/.codex. Heuristic — report wording must
# reflect uncertainty.
detect_plugin() {
  needle="$1"
  for f in \
    "$HOME/.claude/settings.json" \
    "$HOME/.claude/settings.local.json" \
    "$(pwd)/.claude/settings.json" \
    "$(pwd)/.claude/settings.local.json" \
    "$HOME/.codex/settings.json"; do
    [ -f "$f" ] || continue
    if grep -q "$needle" "$f" 2>/dev/null; then
      echo "settings:$f"
      return 0
    fi
  done
  for d in \
    "$HOME/.claude/plugins" \
    "$HOME/.claude/skills" \
    "$(pwd)/.claude/plugins" \
    "$(pwd)/.claude/skills" \
    "$HOME/.codex/plugins" \
    "$HOME/.codex/skills"; do
    [ -d "$d" ] || continue
    if find "$d" -maxdepth 3 -iname "*$needle*" 2>/dev/null | grep -q .; then
      echo "dir:$d"
      return 0
    fi
  done
  return 1
}

if loc=$(detect_plugin superpowers); then
  ok "superpowers: detected by doctor heuristic ($loc)"
else
  warn "superpowers: not detected by doctor (heuristic)"
  optional_missing=$((optional_missing+1))
  add_step "superpowers (optional): /plugin marketplace add obra/superpowers-marketplace then /plugin install superpowers@superpowers-marketplace"
fi

if loc=$(detect_plugin compound-engineering); then
  ok "compound-engineering: detected by doctor heuristic ($loc)"
else
  warn "compound-engineering: not detected by doctor (heuristic)"
  optional_missing=$((optional_missing+1))
  add_step "compound-engineering (optional): install via Claude Code or Codex /plugins UI"
fi

# ---------- [--fix mode] ----------
if [ "$FIX" -eq 1 ]; then
  echo -e "\n${CYAN}[--fix] Attempting safe automatic fixes${NC}"
  echo -e "${GRAY}Only tools with clear CLI installation flows are auto-installed.${NC}"

  fix_confirm() {
    if [ "$FIX_YES" -eq 1 ]; then return 0; fi
    printf "  %s [y/N] " "$1"
    read -r _a
    case "$_a" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
  }

  fix_auto=(); fix_skip=(); fix_manual=(); fix_fail=()

  gstack_dir="$CLAUDE_HOME/skills/gstack"
  if [ -d "$gstack_dir" ]; then
    fix_skip+=("gstack (already installed)")
  elif ! command -v git >/dev/null 2>&1; then
    fix_fail+=("gstack: git missing")
  elif fix_confirm "Clone gstack into $gstack_dir and run setup?"; then
    mkdir -p "$CLAUDE_HOME/skills"
    if git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$gstack_dir"; then
      if [ -f "$gstack_dir/setup" ]; then
        ( cd "$gstack_dir" && bash ./setup ) && fix_auto+=("gstack") \
          || fix_fail+=("gstack setup: cd $gstack_dir && ./setup")
      else
        fix_manual+=("gstack: cd $gstack_dir && ./setup (no setup script auto-detected)")
      fi
    else
      fix_fail+=("gstack clone: git clone https://github.com/garrytan/gstack.git $gstack_dir")
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
  [ ${#fix_auto[@]} -gt 0 ]   && { echo -e "  ${GREEN}installed:${NC}";  for x in "${fix_auto[@]}";   do echo "    - $x"; done; }
  [ ${#fix_skip[@]} -gt 0 ]   && { echo -e "  ${GRAY}skipped:${NC}";     for x in "${fix_skip[@]}";   do echo "    - $x"; done; }
  [ ${#fix_manual[@]} -gt 0 ] && { echo -e "  ${YELLOW}manual:${NC}";    for x in "${fix_manual[@]}"; do echo "    - $x"; done; }
  [ ${#fix_fail[@]} -gt 0 ]   && { echo -e "  ${RED}failures:${NC}";     for x in "${fix_fail[@]}";   do echo "    - $x"; done; }
  echo -e "${GRAY}Re-run doctor.sh (without --fix) to see updated status.${NC}"
fi

# ---------- [recommended next steps] ----------
if [ ${#NEXT_STEPS[@]} -gt 0 ]; then
  echo -e "\n${CYAN}[recommended next steps]${NC}"
  for s in "${NEXT_STEPS[@]}"; do echo "  - $s"; done
fi

echo ""
if [ "$required_missing" -gt 0 ] || [ "$vibekit_missing" -gt 0 ] || [ "$hooks_unparseable" -eq 1 ]; then
  echo -e "${RED}ACTION REQUIRED${NC}"
  exit 2
elif [ "$optional_missing" -gt 0 ] || [ "$SAFE_HOOKS_CONFIGURED" -lt 2 ]; then
  echo -e "${YELLOW}PARTIAL${NC}"
  echo -e "${GRAY}Core commands installed; some optional integrations or safe-mode hooks${NC}"
  echo -e "${GRAY}are not configured. Audit-only flows are still usable.${NC}"
  exit 1
else
  echo -e "${GREEN}READY${NC}"
  exit 0
fi
