# Installation Guide

This guide describes how Vibekit installs itself, what each install mode changes, how to verify with `doctor`, and how to recover or uninstall.

## Prerequisites

| Tool | Required | Notes |
|------|----------|-------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | yes | `claude` CLI must be on PATH |
| Node.js 20+ | yes | for BMAD and many gstack helpers |
| Git | yes | |
| Python 3 | yes | used by the installer for safe JSON merging and by the dangerous-git hook |
| [Codex CLI](https://github.com/openai/codex) | optional | `npm install -g @openai/codex` |

## Path detection

The installer picks the install root in this order:

1. `--claude-home <path>` / `-ClaudeHome <path>` (explicit path).
2. `--scope project` / `-Scope project` → `./.claude` under the current
   working directory.
3. `CLAUDE_HOME` / `$env:CLAUDE_HOME` environment variable.
4. Default: `~/.claude` (Bash) or `<UserProfile>\.claude` (PowerShell).

Override by exporting `CLAUDE_HOME` (or `$env:CLAUDE_HOME` on Windows)
before running, or by passing `--claude-home` explicitly.

## Install scope

| Scope | Path | Affects | When to use |
|-------|------|---------|-------------|
| `global` (default) | `~/.claude` | every Claude Code session on this user account | personal default workstation |
| `project` | `./.claude` of the current project | only that project's Claude Code session | cautious users, teams, shared accounts |

Project scope writes its settings to `settings.local.json` (Claude Code's
machine-local convention) so the file is typically gitignored. Running
project-scope install inside the Vibekit repo itself prints a warning and
requires confirmation (`--yes` / `-Yes` to skip the prompt). Same-file copies
inside the repo are skipped rather than failing.

## Install modes

You **must** pick a mode. The installer does not assume one for you.

### `commands-only`

Safest. Recommended for first-time evaluation.

- Creates `~/.claude/{commands,hooks,learnings/...}` if missing.
- Copies the five slash commands into `~/.claude/commands`.
- Does **not** install hooks.
- Does **not** modify `settings.json`.

### `safe` (recommended)

- Everything in `commands-only`.
- Copies hook scripts into `~/.claude/hooks`.
- Backs up `~/.claude/settings.json` to `settings.json.backup-YYYYMMDD-HHMMSS`.
- Merges only two entries into `settings.json`:
  - `PreToolUse` on `Bash` → `block-dangerous-git.py`
  - `SessionStart` → `session-start.sh`
- Unrelated existing settings are preserved.
- Auto-save / auto-commit is **not** enabled.

### `full`

For power users only. Most users should stay on `safe`.

- Everything in `safe`.
- Additionally enables `PostToolUse` on `Edit|Write|MultiEdit` → `auto-save.sh`.
- `auto-save.sh` now runs a series of safeguards before staging anything. It refuses to commit when: not in a git repo, on `main`/`master`, the change set contains risky filenames (`.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa`, `id_ed25519`, `.claude/settings.json`, `.claude/settings.local.json`), the diff contains obvious secret patterns (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `BEGIN PRIVATE KEY`, `sk-…`), the change set exceeds `HWAN_AUTOSAVE_MAX_FILES` (default 30), or any files were deleted (override with `HWAN_AUTOSAVE_ALLOW_DELETIONS=1`).
- On pass, the hook still runs `git add -A && git commit -m "autosave: claude changes <timestamp>"` — i.e. it stages **the entire working tree**, including files Claude Code did not touch. The safeguards just make the worst cases harder to hit.
- The installer prints an explicit warning before enabling this. Use only if you understand and want that workflow.
- Kill switch: set `HWAN_AUTOSAVE_DISABLE=1` to make the hook exit immediately without uninstalling.

**Recommendation:** most users should pick `safe` (or `commands-only` for the absolute minimum). Pick `full` only if you already work on disposable feature branches with a clean working tree.

## macOS / Linux / WSL

```bash
git clone https://github.com/YOUR-USERNAME/claude-codex-vibekit.git
cd claude-codex-vibekit
./install.sh --mode safe
./doctor.sh
```

Other variants:

```bash
./install.sh --mode commands-only
./install.sh --mode full
./install.sh --mode safe --scope project           # install into ./.claude
./install.sh --mode safe --claude-home /custom/dir # explicit path
./install.sh --help
```

## Windows PowerShell

```powershell
git clone https://github.com/YOUR-USERNAME/claude-codex-vibekit.git
cd claude-codex-vibekit
.\install.ps1 -Mode safe
.\doctor.ps1
```

If PowerShell blocks the script, use:
```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Mode safe
```

## Doctor

`doctor.sh` / `doctor.ps1` inspect the environment and print a report in four
sections:

- `[core readiness]` — required tools (git, node>=20, python, claude CLI)
  and the five Vibekit command files.
- `[hook configuration]` — what hook entries are wired in `settings.json` /
  `settings.local.json` (project scope).
- `[optional integrations]` — codex, BMAD, gstack, plugin detection. Plugin
  presence is heuristic.
- `[recommended next steps]` — one-line fix command per missing item.

Verdicts:

- `READY` — required tools present, core Vibekit commands installed, both
  safe-mode hooks (`PreToolUse`, `SessionStart`) configured, no optional gaps.
- `PARTIAL` — core OK, but one or more of: optional integrations missing
  (codex, gstack, BMAD, plugins); safe-mode hooks not configured (typical for
  `commands-only` installs). Audit-only command flows still work.
- `ACTION REQUIRED` — required tool missing, core command files missing, or
  `settings.json` is unparseable.

Exit codes: `0` READY, `1` PARTIAL, `2` ACTION REQUIRED. Useful for scripting
and for CI smoke tests, which treat 0 and 1 as success.

```bash
./doctor.sh                            # global
./doctor.sh --scope project            # inspect ./.claude
./doctor.sh --claude-home /custom/dir  # explicit path
```

## Opt-in bootstrap

By default, the installer never installs external tools. Pass `--bootstrap`
(or `-Bootstrap` on PowerShell) to opt in to safe automatic install for tools
with clear CLI flows:

```bash
./install.sh --mode safe --bootstrap                # interactive prompts
./install.sh --mode safe --bootstrap --yes          # non-interactive
./install.sh --mode safe --bootstrap --bootstrap-codex  # also install codex globally
```

```powershell
.\install.ps1 -Mode safe -Bootstrap
.\install.ps1 -Mode safe -Bootstrap -Yes
.\install.ps1 -Mode safe -Bootstrap -BootstrapCodex
```

Bootstrap will:

- Clone gstack into `~/.claude/skills/gstack` and run its `./setup` (if `git`
  is available and you confirm).
- If `--bootstrap-codex` / `-BootstrapCodex` is also passed and `npm` is
  available, run `npm install -g @openai/codex`.
- Print exact commands for everything that remains manual: BMAD (project-local,
  `npx bmad-method install`), superpowers (`/plugin marketplace add
  obra/superpowers-marketplace` then `/plugin install
  superpowers@superpowers-marketplace`), and compound-engineering (Claude Code
  or Codex `/plugins` UI).

At the end, bootstrap prints a report split into: **installed automatically**,
**skipped**, **manual steps required**, **failures with recovery commands**.

`doctor --fix` / `doctor -Fix` runs the same safe-auto-install pass against
an existing install:

```bash
./doctor.sh --fix
./doctor.sh --fix --yes
```

```powershell
.\doctor.ps1 -Fix
.\doctor.ps1 -Fix -Yes
```

## Optional integrations

The installer **does not silently install** these. Without `--bootstrap`,
doctor will just tell you which are missing and how to add them. With
bootstrap or `--fix`, the listed tools can be auto-installed (see above);
the rest still require manual steps.

### gstack

```bash
# macOS / Linux / WSL
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack
./setup
```
```powershell
# Windows PowerShell
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$env:USERPROFILE\.claude\skills\gstack"
cd "$env:USERPROFILE\.claude\skills\gstack"
.\setup
```

### BMAD

```bash
npx bmad-method install   # runs per-project
```
BMAD is often project-local. Doctor will report it as missing if not preinstalled, but this does not block Vibekit usage.

### superpowers and compound-engineering

Install through Claude Code's `/plugins` UI (or, for Codex compatibility, through its plugin UI where applicable). Vibekit does not copy plugin files itself.

### Codex CLI

```bash
npm install -g @openai/codex
```

Codex is optional. Missing Codex does not block the Claude Code workflow.

## Idempotency

All scripts are designed to be re-runnable:

- File copies overwrite the matching slash command and hook files only.
- Unrelated user commands in `~/.claude/commands` are not touched.
- Hook entries in `settings.json` are added only if not already present (matched on event + matcher + command).
- Other `settings.json` keys are preserved.

## Manual recovery

If something goes wrong:

1. The installer always writes `settings.json.backup-YYYYMMDD-HHMMSS` before modifying. List them:
   ```bash
   ls -1 ~/.claude/settings.json.backup-* 2>/dev/null
   ```
   Restore the most recent:
   ```bash
   cp ~/.claude/settings.json.backup-YYYYMMDD-HHMMSS ~/.claude/settings.json
   ```
2. If `settings.json` is unparseable, the installer refuses to overwrite it. Fix or restore from a backup, then re-run.
3. If hooks misbehave, switch to `commands-only` mode by running the uninstaller and then `--mode commands-only`.

## Uninstall

```bash
./uninstall.sh                       # global, prompts
./uninstall.sh --yes                 # global, non-interactive
./uninstall.sh --scope project --yes # project-local
```
```powershell
.\uninstall.ps1
.\uninstall.ps1 -Yes
.\uninstall.ps1 -Scope project -Yes
```

The uninstaller:
- removes the five vibekit slash commands and three hook scripts from `~/.claude`.
- backs up `settings.json`, then removes only the hook entries vibekit added.
- preserves your `learnings/` directory (delete manually if desired).

## Troubleshooting

**Slash command not appearing**
Restart Claude Code so it reloads `~/.claude/commands`.

**Hooks not firing**
Inspect `~/.claude/settings.json`. Doctor's `[settings.json hook entries]` section reports which commands are wired up. The installer always uses absolute paths.

**`python` not found on Windows**
Install Python 3 from python.org or the Microsoft Store. The installer needs it for safe JSON merging.

**`bmad-method` reports missing**
This is normal until you run `npx bmad-method install` in a project. It does not block Vibekit commands.

**gstack commands fail**
`gstack` may require per-project setup. See gstack's README.

**Permission denied on macOS / Linux hooks**
```bash
chmod +x ~/.claude/hooks/*.sh ~/.claude/hooks/*.py
```
