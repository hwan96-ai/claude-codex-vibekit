# Release Process Guardrails

Concise process notes captured from the v0.2.5 release cycle and the
post-v0.2.5 maintenance cycle. Living document — keep it short.

## Before you tag

1. **Start from a clean main.** `git checkout main && git pull --ff-only origin main && git status --short`. Never tag from a feature branch or a worktree on an unrelated session branch.
2. **Verify `README.md` and `CHANGELOG.md` after the tag is final.** The README's "Current release verification (vX.Y.Z)" pin and the CHANGELOG entry must reference the actual tag you cut. Avoid commit-SHA pins that drift as the tag's source changes.
3. **Regenerate `SHA256SUMS` whenever a release-relevant file changes.** The release file list lives in [`scripts/generate-checksums.sh`](../../scripts/generate-checksums.sh) (`FILES=...`) and [`tests/test-checksums.sh`](../../tests/test-checksums.sh) (`required=...`). Anything inside that list — installer, doctor, hooks, uninstall, slash commands — needs a regen in the same PR that touched it.
4. **Avoid placeholder/RC wording in the published release.** Strip any "release candidate", "TBD", or "vX.Y.Z-rc" wording before tagging.

## Generating SHA256SUMS on Windows

The Windows checkout may have CRLF working-tree files due to `core.autocrlf=true`, even though `.gitattributes` pins `eol=lf` for tracked release files. Hashing those CRLF files would produce values that **break Linux verification**.

Two safe options:

- **Run the generator on Linux/CI.** Easiest and authoritative.
- **Hash from committed/staged git blobs on Windows.** The blob is always LF-normalized for these files. Use [`scripts/checksums-from-blobs.py`](../../scripts/checksums-from-blobs.py):
  ```bash
  python3 scripts/checksums-from-blobs.py --check    # verify SHA256SUMS against blobs
  python3 scripts/checksums-from-blobs.py            # regenerate SHA256SUMS from blobs
  ```
  Reads the release file list from `scripts/generate-checksums.sh` (single source of truth). Changed files must be staged (`git add <file>`) so `git show :file` resolves to the new content.

Validate locally with `bash tests/test-checksums.sh` — the CRLF-tolerant test added in #18 will report committed-blob matches with a `CRLF artifact` diagnostic on Windows checkouts.

## Working with autosave during PR prep

The project's autosave hook auto-commits edits while you work. Useful during exploration; harmful during PR prep where you want one clean commit.

- **Scope `HWAN_AUTOSAVE_DISABLE=1` to the commit command** (`HWAN_AUTOSAVE_DISABLE=1 git commit -m …`). The autosave path only runs on `PostToolUse:Edit|Write|MultiEdit`, so it cannot fire from the commit itself — but having an explicit guard is still good hygiene.
- **Recover an unwanted autosave commit with `git reset --soft origin/<base>`.** This rewinds the autosave commits while preserving the working-tree changes for a clean recommit. Never use `--hard` here; you lose the work.
- **Don't squash autosave commits into a published PR.** Reset to base before opening the PR and commit once with a real message.

## Worktrees and `gh pr merge --delete-branch`

If your branch is checked out in a worktree, `gh pr merge --delete-branch` will refuse to delete the local branch (it's in use). The remote branch deletes; the local one lingers. Either switch the worktree off the branch first, or accept the local stale branch and prune later (`git worktree remove …`, `git branch -d …`).

## CI failure handling

- **Stop and report on first red.** Don't open the next PR before the failing one is understood. CI failures usually point at a real issue.
- **`mergeStateStatus` must be `CLEAN`.** `gh pr view <n> --json mergeStateStatus,mergeable,state` — anything else (`BEHIND`, `BLOCKED`, `DIRTY`) means do not merge.
- **One PR per concern.** Mixing unrelated changes makes failures hard to bisect and forces correlated rollbacks.

## After every merge

```bash
git checkout main
git pull --ff-only origin main
git tag --sort=-creatordate | head -3   # confirm no new tags
gh release view <latest> --json tagName,isDraft,isPrerelease,assets   # confirm release still intact
```
