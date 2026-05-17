# Security & install modes

This document explains, in plain terms, what the Vibekit installer changes on your machine, what it never does, and how to back out.

The kit is a local quality-gate layer for Claude Code (and optionally Codex CLI). It is not an autonomous agent. Inspect the scripts before running them if you have any concern — they are short.

## What the installer modifies

The installer writes only inside `~/.claude` (or `$CLAUDE_HOME` if set). It does not touch your repositories, system PATH, shell rc files, or any other directory.

Specifically:

- Creates if missing:
  - `~/.claude/commands/`
  - `~/.claude/hooks/`
  - `~/.claude/learnings/{idea,code,design,git}/`
- Copies five slash commands into `~/.claude/commands/`:
  - `git-safe.md`
  - `hwan-refactor-idea.md`
  - `hwan-refactor-code.md`
  - `hwan-refactor-design.md`
  - `hwan-refactor-git.md`
- In `safe` and `full` modes only, copies three hook scripts into `~/.claude/hooks/`:
  - `block-dangerous-git.py`
  - `session-start.sh`
  - `auto-save.sh` (file is copied, but only registered in `full` mode)
- In `safe` and `full` modes only, merges hook entries into `~/.claude/settings.json`.

Existing files in `~/.claude/commands` that are not in the list above are not touched. Unrelated keys in `settings.json` are preserved.

## What lives in `~/.claude`

`~/.claude` is Claude Code's global configuration directory. Hooks and commands placed here are visible to **every** Claude Code session on this user account, regardless of the project. That is by design — but it means a hook you enable globally will run for all projects, not only this one.

## Install modes

| Mode | Hooks copied | Hook entries in settings.json | Risk profile |
|------|--------------|-------------------------------|--------------|
| `commands-only` | none | none | minimal — only adds slash commands you can invoke explicitly |
| `safe` | yes | `PreToolUse:Bash` (block dangerous git) and `SessionStart` (branch safety) | low — hooks only block clearly dangerous git operations and create a working branch |
| `full` | yes | `safe` + `PostToolUse:Edit|Write|MultiEdit` (auto-save / auto-commit) | medium — automatic commits will be created after file changes |

`full` mode enables **auto-save / auto-commit**. After Claude Code edits a file, the `auto-save.sh` hook runs a series of safeguards and, only if all of them pass, commits with `git add -A`.

The hook refuses to commit if any of these are true:

- not inside a git work tree
- current branch is `main`/`master`
- the change set includes risky filenames: `.env`, `.env.*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa`, `id_ed25519`, `.claude/settings.json`, `.claude/settings.local.json`
- the diff (staged, unstaged, or untracked file contents) contains obvious secret patterns: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `BEGIN PRIVATE KEY`, `sk-…`
- the change set is larger than `HWAN_AUTOSAVE_MAX_FILES` (default 30)
- any files were deleted, unless `HWAN_AUTOSAVE_ALLOW_DELETIONS=1`

On pass, the hook prints a short summary (branch, file count, paths) and then runs:

```
git add -A
git commit -m "autosave: claude changes <timestamp>"
```

**Even with all those checks, the commit still stages the entire working tree** (including files Claude Code did not touch — build artifacts, scratch files, in-progress changes from other tools). The safeguards reduce the worst cases; they do not change the fundamental tradeoff. If you keep `full` mode enabled, work on a clean working tree or move scratch files outside the repo. If that does not fit your workflow, choose `safe` (recommended) or `commands-only`. The installer prints an explicit warning before enabling `full`.

Kill switch and tuning (environment variables read by `auto-save.sh`):

| Variable | Effect |
|----------|--------|
| `HWAN_AUTOSAVE_DISABLE=1` | Hook exits immediately, never commits. |
| `HWAN_AUTOSAVE_MAX_FILES=N` | Override the 30-file cap. |
| `HWAN_AUTOSAVE_ALLOW_DELETIONS=1` | Allow commits that delete files. |

### Global hook scope

Hooks live in `~/.claude/hooks` and are wired up through `~/.claude/settings.json`, which is Claude Code's **global** config. A hook registered there fires for **every** Claude Code session on this user account, not only for projects in this directory. That is by design but worth knowing — if you share an account across many projects, all of them inherit these hooks. To avoid that entirely, install with `--mode commands-only`.

## What the installer never does

- Never pushes to a remote.
- Never creates pull requests.
- Never merges branches.
- Never deploys.
- Never installs Claude Code, Node.js, gstack, BMAD, superpowers, compound-engineering, or Codex without opt-in. By default the installer only prints exact instructions. `--bootstrap` / `-Bootstrap` (and the matching `doctor --fix` / `-Fix`) is an explicit opt-in that may clone gstack and run its `./setup`; `--bootstrap-codex` / `-BootstrapCodex` additionally allows a global `npm install -g @openai/codex`. BMAD, superpowers, and compound-engineering remain manual even in bootstrap mode — BMAD because it is project-local, the plugins because they must go through Claude Code's plugin UI.
- Never silently enables auto-commit. You must pick `--mode full` explicitly.
- Never overwrites unrelated keys in your `settings.json`.
- Never deletes user commands or hooks it did not place.

## settings.json backup and merge

Before any modification, the installer copies `~/.claude/settings.json` to:

```
~/.claude/settings.json.backup-YYYYMMDD-HHMMSS
```

Backups accumulate; delete old ones manually if you want.

Merge logic (Python, not shell string manipulation):

- Reads the existing JSON. If it cannot be parsed, the installer aborts without writing.
- For each hook entry it wants to add, it checks whether an identical entry (same event + matcher + command string) already exists. If yes, it does nothing.
- Other keys are left intact.

## How to uninstall

```bash
./uninstall.sh           # or .\uninstall.ps1 on Windows
```

This removes the slash commands and hook scripts Vibekit installed, backs up `settings.json`, and strips out only the hook entries Vibekit added. Your `learnings/` directory is preserved; delete manually if desired.

## How to report security issues

If you find a security problem, please open a private security advisory on the repository, or email the maintainer. Please do **not** open a public issue with reproduction details for an unpatched vulnerability.

## Reading the scripts yourself

The installer, doctor, and uninstaller are short and well-commented:

- `install.sh`, `install.ps1`
- `doctor.sh`, `doctor.ps1`
- `uninstall.sh`, `uninstall.ps1`

You are encouraged to read them before running. If you only want the slash commands and no hooks at all, run with `--mode commands-only` (or `-Mode commands-only`).
