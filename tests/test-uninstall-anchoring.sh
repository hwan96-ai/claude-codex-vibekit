#!/usr/bin/env bash
# Verifies uninstall.sh strips only vibekit's own hook entries, not unrelated
# user hooks that happen to share a basename. Regression test for the
# bare-basename substring matching that existed prior to v0.2.6.
#
# Run from repo root:  bash tests/test-uninstall-anchoring.sh
# Exit non-zero on failure.

set -u

cd "$(dirname "$0")/.."
REPO="$(pwd)"

fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

CLAUDE_HOME="$tmp/claude_home"
mkdir -p "$CLAUDE_HOME/hooks"
# Stage realistic hook files so the file-removal step in uninstall.sh works.
for f in block-dangerous-git.py session-start.sh auto-save.sh auto-save-payload.py; do
  : > "$CLAUDE_HOME/hooks/$f"
done

# Build settings.json via python so JSON escaping (including a backslash
# Windows-style path for one entry) is correct.
python3 - "$CLAUDE_HOME/settings.json" "$CLAUDE_HOME" <<'PYEOF'
import json, sys
settings_path, claude_home = sys.argv[1], sys.argv[2]
data = {
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write|MultiEdit",
      "hooks": [
        # Project's own auto-save hook — MUST be removed.
        {"type": "command", "command": "bash " + claude_home + "/hooks/auto-save.sh"},
        # Unrelated user hook with matching basename in a non-hooks/ path —
        # MUST be preserved. Pre-anchoring uninstaller stripped this.
        {"type": "command", "command": "bash /usr/local/bin/auto-save.sh"},
      ],
    }],
    "SessionStart": [{
      "matcher": "",
      "hooks": [
        # Project's session-start hook written with Windows-style backslash
        # path — MUST be removed.
        {"type": "command", "command": r"bash C:\Users\alice\.claude\hooks\session-start.sh"},
      ],
    }],
    "Other": [{
      "matcher": "",
      "hooks": [
        # Completely unrelated hook — MUST be preserved.
        {"type": "command", "command": "echo unrelated"},
      ],
    }],
  }
}
with open(settings_path, "w") as f:
  json.dump(data, f, indent=2)
PYEOF

HWAN_AUTOSAVE_DISABLE=1 bash "$REPO/uninstall.sh" --yes --claude-home "$CLAUDE_HOME" >/dev/null 2>&1

if grep -q "$CLAUDE_HOME/hooks/auto-save.sh" "$CLAUDE_HOME/settings.json"; then
  echo "FAIL: project's own auto-save.sh entry was NOT removed"; fail=$((fail+1))
else
  echo "ok  : project auto-save.sh entry removed"
fi
if grep -q "/usr/local/bin/auto-save.sh" "$CLAUDE_HOME/settings.json"; then
  echo "ok  : unrelated /usr/local/bin/auto-save.sh entry preserved"
else
  echo "FAIL: unrelated user hook with matching basename was wrongly removed"
  fail=$((fail+1))
fi
if grep -q "session-start.sh" "$CLAUDE_HOME/settings.json"; then
  echo "FAIL: project session-start.sh (backslash path) was NOT removed"
  fail=$((fail+1))
else
  echo "ok  : project session-start.sh backslash entry removed"
fi
if grep -q "echo unrelated" "$CLAUDE_HOME/settings.json"; then
  echo "ok  : completely unrelated hook preserved"
else
  echo "FAIL: completely unrelated hook was wrongly removed"; fail=$((fail+1))
fi

if [ "$fail" -gt 0 ]; then
  echo "FAILED ($fail check(s))"
  exit 1
fi
echo "All anchoring checks passed."
