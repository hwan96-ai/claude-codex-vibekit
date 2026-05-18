# GitHub publishing checklist

Practical notes for keeping the repo presentable on GitHub. Maintainer-facing.

## Recommended topics

Set these in **Settings → General → Topics**:

- `claude-code`
- `codex-cli`
- `ai-coding`
- `quality-gates`
- `developer-tools`
- `vibe-coding`
- `cli-tools`
- `workflow-automation`

Topics improve discoverability and tell GitHub how to surface the repo on
the Explore feed and in topic pages.

## Release checklist

1. Branch `docs/<topic>` or `feat/<topic>` is merged into `main` via PR.
2. Local main is up to date:
   ```bash
   git checkout main && git pull --ff-only
   ```
3. Regenerate and verify `SHA256SUMS` against the tree you are about to
   tag (mismatch here means an earlier commit changed a release file
   without refreshing checksums):
   ```bash
   bash scripts/generate-checksums.sh
   git diff --exit-code SHA256SUMS || git add SHA256SUMS
   ```
4. Run doctor hook runtime verification against a throwaway CLAUDE_HOME
   to confirm hooks still install and behave:
   ```bash
   tmp="$(mktemp -d)"
   ./install.sh --mode safe --claude-home "$tmp"
   ./doctor.sh --claude-home="$tmp" --ci   # expect READY (rc 0)
   ```
5. Update `CHANGELOG.md`: change `## [X.Y.Z] — Unreleased` to
   `## [X.Y.Z] — YYYY-MM-DD`.
6. Commit:
   ```bash
   git add CHANGELOG.md SHA256SUMS
   git commit -m "docs(changelog): release vX.Y.Z"
   ```
7. Tag (annotated):
   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z: <short summary>"
   ```
8. Push main + tag (no force):
   ```bash
   git push
   git push origin vX.Y.Z
   ```
9. Extract release notes (the X.Y.Z section of CHANGELOG.md) and create the
   release. PowerShell-friendly (no process substitution):
   ```bash
   python -c "import re,pathlib; t=pathlib.Path('CHANGELOG.md').read_text(encoding='utf-8'); \
     m=re.search(r'(## \[X\.Y\.Z\].*?)(?=^## \[)', t, re.S|re.M); \
     pathlib.Path('.release-notes.md').write_text(m.group(1).rstrip()+'\n', encoding='utf-8')"
   gh release create vX.Y.Z --title "vX.Y.Z: <short summary>" \
     --notes-file .release-notes.md
   rm .release-notes.md
   ```
   Replace `X\.Y\.Z` with the actual version (escape dots for the regex).
10. (Optional) attach `SHA256SUMS` to the release so it can be downloaded
    independently of a clone:
    ```bash
    gh release upload vX.Y.Z SHA256SUMS
    ```
11. Verify:
    ```bash
    gh release view vX.Y.Z
    ```

Do not mark the release as pre-release unless it actually is.

## How to update README badges

Badges are plain Markdown image links at the top of `README.md` and
`README.ko.md`. Keep them stable:

- **smoke-tests** — must point to `.github/workflows/smoke-tests.yml`. If
  the workflow file is renamed or moved, update the badge URL in both
  READMEs.
- **Latest release** — `img.shields.io` reads the GitHub Releases API; it
  updates on its own when a new release is published. No edit needed per
  release.
- **License / Claude Code / Codex CLI** — static badges; only update if
  the underlying claim changes.

When adding a new badge, verify the URL renders in a private browser
(no GitHub login) before committing.

## How to create release notes from CHANGELOG

The release notes for vX.Y.Z should be the X.Y.Z section of
`CHANGELOG.md`, copied verbatim. The snippet in the release checklist
above extracts that section deterministically with Python so the same
content appears on the GitHub Release page as in the changelog.

Do **not** rewrite or compress notes when pasting into the release page;
keep the changelog the source of truth.

## Post-release smoke test

After publishing a release, do a quick sanity check on a clean machine or
in a temp directory:

```bash
git clone https://github.com/hwan96-ai/claude-codex-vibekit.git /tmp/vibekit-release-check
cd /tmp/vibekit-release-check
git checkout vX.Y.Z
CLAUDE_HOME="$(mktemp -d)" ./install.sh --mode commands-only
CLAUDE_HOME="$CLAUDE_HOME" ./doctor.sh --ci
```

Expect `READY` or `PARTIAL` (rc 0 or 1). `ACTION REQUIRED` (rc 2) means
something regressed and the release should be investigated.

## Recommended social announcement text

Keep it short and accurate. Do not overclaim. Suggested template:

> claude-codex-vibekit vX.Y.Z is out.
>
> A local quality-gate workflow for Claude Code (Codex CLI optional):
> PRD → Code → Design → Release, with safety hooks and audit-only flows.
> Not an AI coding agent. No automatic push/merge/deploy.
>
> Highlights:
> - <bullet 1 from CHANGELOG>
> - <bullet 2>
>
> Repo + install instructions:
> https://github.com/hwan96-ai/claude-codex-vibekit

Avoid: "production-ready", "battle-tested", "one-command install",
"verified at every step". The kit is 0.x; let people form their own opinion.
