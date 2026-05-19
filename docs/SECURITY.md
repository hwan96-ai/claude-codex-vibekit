# Security & install modes

This document explains, in plain terms, what the Vibekit installer changes on your machine, what it never does, and how to back out.

## Quick trust summary

- `commands-only` — safest. Slash commands only. No hooks. No `settings.json` changes.
- `safe` — recommended. Adds two safety-only hooks. **Auto-commit is not enabled.**
- `full` — power user only. Adds auto-save/auto-commit. Even with all safeguards, the fallback path stages the working tree. Read the rest of this doc before enabling.
- **Global** hooks affect every Claude Code session on this account. **Project scope** (`--scope project`) confines everything to `./.claude` and is the safer choice for shared accounts and team repos.
- The installer **never** pushes, creates PRs, merges, or deploys.
- `--bootstrap` / `-Bootstrap` and `doctor --fix` / `-Fix` are **opt-in**; without them the installer does not install any external tool.

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
| `HWAN_AUTOSAVE_STAGE_MODE=auto\|payload\|all` | Staging strategy. Default `auto`. |

Staging modes (`HWAN_AUTOSAVE_STAGE_MODE`):

- `auto` (default) — parse the Claude Code hook stdin payload. If a
  validated, in-repo file list is found, stage only those files. Otherwise
  fall back to guarded `git add -A`.
- `payload` — require a payload file list; refuse to commit if absent or
  invalid. Strictest mode; useful when you do not want any blanket staging.
- `all` — skip payload parsing and use guarded `git add -A` directly
  (pre-v0.1.3 behavior).

Payload-aware staging is conservative: paths must resolve inside the git
work tree, must currently exist as files, and known-payload fields are
limited to `tool_input.{file_path, filePath, path, files, edits[].*}`.
Anything outside that contract is rejected and the hook falls back (auto)
or refuses (payload). Even with payload mode, all the other safeguards
(branch, risky paths, secret patterns, file count) still apply.

### Global hook scope

Hooks live in `~/.claude/hooks` and are wired up through `~/.claude/settings.json`, which is Claude Code's **global** config. A hook registered there fires for **every** Claude Code session on this user account, not only for projects in this directory. That is by design but worth knowing — if you share an account across many projects, all of them inherit these hooks. To avoid that entirely, install with `--mode commands-only` or use **project scope** (below).

### Project scope as an alternative

`--scope project` (Bash) / `-Scope project` (PowerShell) installs commands,
hooks, and settings into `./.claude` instead of `~/.claude`, and writes
settings to `settings.local.json` to match Claude Code's machine-local
convention. Hooks installed this way affect only that project. This is the
recommended scope for cautious users, shared accounts, and teams.

### Plugin detection caveat

Doctor's check for `superpowers` and `compound-engineering` looks at
`settings.json`, `settings.local.json`, and known plugin / skill directories
under both `~/.claude` and `~/.codex`, plus the project-local `./.claude`.
This is still a heuristic: presence of the substring in a settings file or a
matching directory name suggests the plugin is installed, but doctor cannot
guarantee it. Output uses "not detected by doctor" rather than "not
installed" for that reason.

## What the `block-dangerous-git.py` hook actually blocks

The PreToolUse hook (`safe` and `full` modes) blocks destructive or
history-rewriting git operations. It does **not** block normal pushes, even
to `main` — releasing from `main` is a legitimate, intentional action and
the user must remain in control of it.

Blocked:

- `git push --force`, `git push -f`, `git push --force-with-lease[=...]`
- `git reset --hard`
- `git clean -f` / `-fd` / `-xdf` / `--force` (any variant with the force flag)
- `git checkout -- .` (discards all local changes)
- `git push <remote> --delete <main|master>` and `git push <remote> :<main|master>`
- `git push <remote> +<refspec>` — any refspec prefixed with `+` is a
  force-update and is treated as a force push (e.g. `+main`, `+HEAD:main`,
  `+feature:main`, `+refs/heads/feature:refs/heads/main`)
- `git branch -D <name>`
- `git commit --amend`
- `git rebase` while the current branch is `main` / `master`
- `git commit` / `git merge` while the current branch is `main` / `master`
- `rm -rf /`

Not blocked:

- `git push origin main`, `git push -u origin main`, `git push`,
  `git push origin HEAD:main`
- `git push origin --tags`, `git push origin v0.1.2`
- `git push -u origin feat/whatever`
- `git commit -m "fix main bug"` on a feature branch (the word "main" in a
  commit message is irrelevant)

The hook decides "are we on a protected branch?" by running
`git rev-parse --abbrev-ref HEAD`, not by string-matching `main` in the
command line. Set `VIBEKIT_HOOK_TEST_BRANCH=<name>` to override branch
detection in tests.

PR creation, merge, and deploy remain manual in every mode. The hook does
not push, merge, or deploy on the user's behalf.

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

## Supply-chain limitations and release integrity

Vibekit ships a `SHA256SUMS` file at the repository root covering the 15
release-relevant files (install / doctor / uninstall scripts on both
platforms, all four hooks, all five slash commands). Two cross-platform
scripts regenerate or verify it:

- `scripts/generate-checksums.sh` (Bash, falls back to `shasum -a 256` on
  macOS if `sha256sum` is absent).
- `scripts/generate-checksums.ps1` (PowerShell, uses `Get-FileHash`).

Both produce **byte-identical** output (`<sha256>  <relative/path>`, two
spaces, lowercase hash, forward-slash paths). To verify a fresh clone:

```bash
git checkout v0.2.5
bash scripts/generate-checksums.sh --check
```

**What `SHA256SUMS` does protect against**

- Download-path tampering (corrupt mirror, MITM during clone).
- Accidental file corruption (partial clone, disk error, encoding rewrite).
- Local tampering you want to detect after install (rerun `--check` from a
  clean copy).

**What `SHA256SUMS` does NOT protect against**

- A compromised repository owner account that publishes a malicious tag
  alongside a malicious `SHA256SUMS`. The file is self-attested by the
  owner; it is not a third-party signature.
- A compromised GitHub release page where both the file and the published
  hashes are replaced together.
- Vulnerabilities in upstream tools the kit invokes (gstack, BMAD,
  superpowers, compound-engineering, Codex CLI, Claude Code itself).

The practical upgrade is: **prefer a tagged release over a moving `main`**.
Tags are immutable references; you can verify the same SHA256SUMS on every
clone you make of that tag.

## Hook runtime verification

Copying a hook file is not the same as having a working hook. OS security
tools — Gatekeeper quarantine on macOS, Windows Defender, SELinux/AppArmor
on Linux — can silently quarantine or block execution after a successful
`cp` or `Copy-Item`. The installer and doctor cannot fully control those
tools from userspace, but they can verify that the installed files actually
behave as expected.

Both `install.sh` and `install.ps1` now run `[4.5] Verifying installed
hooks (post-copy runtime smoke)` after copying hooks and merging settings:

1. Each required hook file is present.
2. Each Python hook compiles under the detected interpreter
   (`python -m py_compile`).
3. Each shell hook passes `bash -n`, where bash is available. On Windows
   without bash this is a warning, not a failure.
4. `block-dangerous-git.py` is given two JSON payloads on stdin and must
   exit with the expected code: `git push origin main` → exit 0 (allow),
   `git push --force` → exit 2 (block).
5. Every hook command path referenced inside `settings.json` /
   `settings.local.json` resolves to a real file on disk.

If any check fails the installer exits non-zero. It does **not** claim
success. It prints OS-specific suggestions (Gatekeeper / Defender /
SELinux) so you can investigate why a file that was copied did not run.

The same five checks live in `doctor.sh` / `doctor.ps1` under
`[hook runtime verification]`, so you can rerun them at any time without
reinstalling. Doctor explicitly distinguishes "configured" (a settings.json
entry exists) from "verified" (the referenced file exists, compiles, and
the primary safety hook actually blocks what it should). Only the latter
counts toward `READY`.

**OS security tools caveat.** We can verify that a hook compiles and runs
in the installer/doctor process. We cannot guarantee that Claude Code will
later be able to execute the same hook under a different user context,
sandboxed shell, or restricted antivirus policy. If you see green from
doctor but the hook does not fire in Claude Code, treat that as a real
finding and investigate the antivirus / quarantine path first.

## How to report security issues

If you find a security problem, please open a private security advisory on the repository, or email the maintainer. Please do **not** open a public issue with reproduction details for an unpatched vulnerability.

## Reading the scripts yourself

The installer, doctor, and uninstaller are short and well-commented:

- `install.sh`, `install.ps1`
- `doctor.sh`, `doctor.ps1`
- `uninstall.sh`, `uninstall.ps1`

You are encouraged to read them before running. If you only want the slash commands and no hooks at all, run with `--mode commands-only` (or `-Mode commands-only`).
