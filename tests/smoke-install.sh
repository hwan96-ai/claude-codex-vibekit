#!/usr/bin/env bash
# Installer smoke test (bash).
# Installs into an isolated CLAUDE_HOME, then runs doctor and asserts all
# five vibekit commands were copied. Treats doctor exit 0 (READY) or 1
# (PARTIAL) as acceptable; exit 2 (ACTION REQUIRED) is a failure.
#
# Required env:
#   CLAUDE_HOME — isolated directory (caller sets this; the script will not
#                 wipe an arbitrary path).
#
# Optional env:
#   VIBEKIT_SMOKE_MODE  default: commands-only
#   VIBEKIT_SMOKE_SCOPE default: global
set -eu

if [ -z "${CLAUDE_HOME:-}" ]; then
  echo "smoke-install.sh: CLAUDE_HOME must be set to an isolated path" >&2
  exit 2
fi

MODE="${VIBEKIT_SMOKE_MODE:-commands-only}"
SCOPE="${VIBEKIT_SMOKE_SCOPE:-global}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "smoke: repo_root=$REPO_ROOT"
echo "smoke: claude_home=$CLAUDE_HOME"
echo "smoke: mode=$MODE scope=$SCOPE"

mkdir -p "$CLAUDE_HOME"

# Use an explicit Claude home path for both install and doctor so the test is
# independent of the current working directory and never accidentally touches
# the kit's own .claude/.
INSTALL_ARGS="--mode $MODE --claude-home $CLAUDE_HOME"
DOCTOR_ARGS="--claude-home=$CLAUDE_HOME --ci"
if [ "$SCOPE" = "project" ]; then
  INSTALL_ARGS="$INSTALL_ARGS --scope project --yes"
  DOCTOR_ARGS="$DOCTOR_ARGS --scope=project"
fi

# Run install from a neutral workdir (not the repo root) so the in-repo
# warning path never triggers.
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# shellcheck disable=SC2086
( cd "$WORKDIR" && bash "$REPO_ROOT/install.sh" $INSTALL_ARGS )

set +e
# shellcheck disable=SC2086
( cd "$WORKDIR" && bash "$REPO_ROOT/doctor.sh" $DOCTOR_ARGS )
DOCTOR_RC=$?
set -e
echo "smoke: doctor rc=$DOCTOR_RC"
if [ "$DOCTOR_RC" -ge 2 ]; then
  echo "smoke: FAIL doctor reported ACTION REQUIRED" >&2
  exit 1
fi

CMD_DIR="$CLAUDE_HOME/commands"

missing=0
for f in hwan-refactor-idea.md hwan-refactor-code.md hwan-refactor-design.md hwan-refactor-git.md git-safe.md; do
  if [ ! -f "$CMD_DIR/$f" ]; then
    echo "smoke: FAIL missing $CMD_DIR/$f" >&2
    missing=$((missing+1))
  fi
done
if [ "$missing" -gt 0 ]; then
  exit 1
fi
echo "smoke: PASS ($CMD_DIR has all 5 commands; doctor rc=$DOCTOR_RC)"
