#!/usr/bin/env bash
# Claude-Codex Vibekit uninstaller (macOS / Linux / WSL)
#
# Removes vibekit slash commands, hook scripts, and the hook entries the
# installer added to ~/.claude/settings.json. Backups the settings file first.
# Other settings keys are preserved.
#
# Usage:
#   ./uninstall.sh                 (prompts to confirm)
#   ./uninstall.sh --yes           (no prompt)

set -u

SCOPE="global"
CLAUDE_HOME_ARG=""
AUTO_YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) AUTO_YES=1; shift ;;
    --scope) SCOPE="${2:-}"; shift 2 ;;
    --scope=*) SCOPE="${1#*=}"; shift ;;
    --claude-home) CLAUDE_HOME_ARG="${2:-}"; shift 2 ;;
    --claude-home=*) CLAUDE_HOME_ARG="${1#*=}"; shift ;;
    -h|--help)
      echo "Usage: $0 [--yes] [--scope global|project] [--claude-home <path>]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -n "$CLAUDE_HOME_ARG" ]; then
  CLAUDE_HOME="$CLAUDE_HOME_ARG"
elif [ "$SCOPE" = "project" ]; then
  CLAUDE_HOME="$(pwd)/.claude"
else
  CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
fi

if [ "$SCOPE" = "project" ]; then
  SETTINGS="$CLAUDE_HOME/settings.local.json"
else
  SETTINGS="$CLAUDE_HOME/settings.json"
fi

echo "Vibekit uninstall plan:"
echo "  scope:       $SCOPE"
echo "  claude_home: $CLAUDE_HOME"
echo "  settings:    $SETTINGS"
echo "  - remove commands/hwan-refactor-*.md and commands/git-safe.md"
echo "  - remove hooks/{block-dangerous-git.py,auto-save.sh,session-start.sh}"
echo "  - remove vibekit-added entries from $SETTINGS (backed up first)"
echo "  - learnings/ are preserved (delete manually if desired)"

if [ "$AUTO_YES" -ne 1 ]; then
  printf "Proceed? [y/N] "
  read -r ans
  case "$ans" in y|Y|yes|YES) ;; *) echo "aborted"; exit 1 ;; esac
fi

removed=0
for f in \
  "$CLAUDE_HOME/commands/hwan-refactor-idea.md" \
  "$CLAUDE_HOME/commands/hwan-refactor-code.md" \
  "$CLAUDE_HOME/commands/hwan-refactor-design.md" \
  "$CLAUDE_HOME/commands/hwan-refactor-git.md" \
  "$CLAUDE_HOME/commands/git-safe.md" \
  "$CLAUDE_HOME/hooks/block-dangerous-git.py" \
  "$CLAUDE_HOME/hooks/auto-save.sh" \
  "$CLAUDE_HOME/hooks/auto-save-payload.py" \
  "$CLAUDE_HOME/hooks/session-start.sh"; do
  if [ -f "$f" ]; then rm -f "$f"; echo "removed $f"; removed=$((removed+1)); fi
done

if [ -f "$SETTINGS" ]; then
  PYTHON_BIN=""
  for c in python3 python; do command -v "$c" >/dev/null 2>&1 && PYTHON_BIN="$c" && break; done
  if [ -z "$PYTHON_BIN" ]; then
    echo "warning: python not found; settings.json not cleaned. Edit manually."
  else
    cp "$SETTINGS" "$SETTINGS.backup-$(date +%Y%m%d-%H%M%S)"
    "$PYTHON_BIN" - "$SETTINGS" <<'PYEOF'
import json, sys, os
p = sys.argv[1]
try:
    with open(p, "r", encoding="utf-8") as f: data = json.load(f)
except Exception as e:
    print(f"could not parse settings.json: {e}"); sys.exit(0)

needles = ("block-dangerous-git.py", "session-start.sh", "auto-save.sh")
hooks = data.get("hooks") or {}
for event in list(hooks.keys()):
    entries = hooks.get(event) or []
    new_entries = []
    for entry in entries:
        inner = entry.get("hooks") or []
        kept = [h for h in inner if not any(n in (h.get("command") or "") for n in needles)]
        if kept:
            entry["hooks"] = kept
            new_entries.append(entry)
    if new_entries:
        hooks[event] = new_entries
    else:
        del hooks[event]
if not hooks and "hooks" in data:
    del data["hooks"]
elif "hooks" in data:
    data["hooks"] = hooks

with open(p, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2); f.write("\n")
print(f"cleaned vibekit hook entries from {p}")
PYEOF
  fi
fi

echo "done. $removed file(s) removed."
echo "If you want to remove learnings: rm -rf $CLAUDE_HOME/learnings"
