# Contributing

Thanks for considering a contribution. Vibekit is an early v0.1.0 release, so
small, well-scoped improvements are the most useful right now.

## Reporting issues

Please include:
- OS and shell (macOS / Linux / WSL / Windows PowerShell).
- Claude Code version (`claude --version`).
- Node and Python versions.
- The install mode you used (`commands-only`, `safe`, or `full`).
- Output of `./doctor.sh` or `.\doctor.ps1`.
- Exact command run and a paste of the relevant output.

If the issue touches security, please open a private security advisory rather
than a public issue. See `docs/SECURITY.md` for details.

## Proposing changes

1. Open an issue first for anything beyond a small fix. Describe the problem
   and the smallest change that addresses it.
2. Keep PRs focused. One concern per PR.
3. Match the existing tone in docs: calm, honest, no overclaiming. See the
   banned phrases list below.
4. Update the relevant docs in the same PR as the behavior change.

## Testing installer changes

For any change to `install.sh`, `install.ps1`, `doctor.*`, or `uninstall.*`:

1. Run the affected installer in a fresh `CLAUDE_HOME` to verify idempotency:
   ```bash
   CLAUDE_HOME=/tmp/vibekit-test ./install.sh --mode commands-only
   CLAUDE_HOME=/tmp/vibekit-test ./install.sh --mode safe       # should not duplicate hook entries
   CLAUDE_HOME=/tmp/vibekit-test ./doctor.sh
   CLAUDE_HOME=/tmp/vibekit-test ./uninstall.sh --yes
   ```
   PowerShell equivalent uses `$env:CLAUDE_HOME`.
2. Run the smoke tests and bash syntax check:
   ```bash
   bash tests/smoke.sh
   bash -n install.sh doctor.sh uninstall.sh .claude/hooks/auto-save.sh
   ```
   On Windows PowerShell:
   ```powershell
   .\tests\smoke.ps1
   ```
3. Parse-check PowerShell if available:
   ```powershell
   foreach ($f in 'install.ps1','doctor.ps1','uninstall.ps1') {
     $tokens=$null; $errs=$null
     [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$tokens, [ref]$errs) | Out-Null
     if ($errs.Count -ne 0) { throw $errs }
   }
   ```
4. Confirm `settings.json` was backed up and that the merge added only the
   intended hook entries.

## Slash commands and skills

- Do not add unverified slash command names to documentation. If a `gstack`,
  `superpowers`, `compound-engineering`, or BMAD command is not confirmed to
  exist by the current repo or by upstream docs, do not list it as a hard
  dependency. Prefer wording like "skills used where available".
- The commands currently shipped by Vibekit are:
  - `git-safe`
  - `hwan-refactor-idea`
  - `hwan-refactor-code`
  - `hwan-refactor-design`
  - `hwan-refactor-git`

## Hook safety

- Do not silently enable risky behavior. Anything that modifies the working
  tree, the index, or remote state must be off by default and gated behind an
  explicit mode (`full`) with a printed warning.
- Backups before mutating `settings.json` are mandatory.
- Hooks must remain idempotent on reinstall.

## Placeholders to leave alone

These are intentionally unfilled in the public repo. Do not replace them:

- `LICENSE` — the `[YOUR NAME]` placeholder.
- `README.md` and `README.ko.md` — the `YOUR-USERNAME` placeholder.

## Documentation tone

Avoid overclaiming. The following phrases are banned in docs and scripts:

- complete workflow
- verified at every step
- mistakes don't repeat
- safety without slowing down
- one command install / one-line install
- production-ready
- battle-tested

Prefer:

- practical workflow
- checks at each step
- repeated mistakes become easier to catch
- lightweight safety layer
- installs commands, then checks integrations
- v0.1.0 initial release

## Documentation required for behavior changes

Any PR that changes installer, doctor, uninstall, or hook behavior must
update at least one of: `README.md`, `docs/INSTALLATION.md`, or
`docs/SECURITY.md`, plus a `CHANGELOG.md` entry under the next version.
