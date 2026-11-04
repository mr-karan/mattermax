# Mattermax development workflow

Mattermax is built from a pinned upstream Mattermost release plus a series of patch files, a branding pass and a settings overlay. Developers work in a throwaway local workspace, export their commits as patches, and every release is built by CI from this repo.

## At a glance

```
mattermost/mattermost ──sync──▶ opnlabs/mattermax-source (read-only mirror)
                                        │ pinned tag (upstream.json)
                                        ▼
            work/src ◀── patches/series (git am, one commit per patch)
                │ copy
                ▼
            work/build/src ◀── branding/rebrand.py (name + icons)
                │ make
                ▼
            work/build/dist ◀── config/overlay.json
                │ tag {version}-{revision}
                ▼
            GitHub release (server + source tarballs) and Docker image
```

Developers only ever write to this repo. CI clones the mirror at the pinned tag, applies the patches, brands a copy of the tree, builds it and merges the settings overlay.

**Key files:**

- `upstream.json`: the mirror URL, the pinned upstream version and its full commit hash.
- `revision`: the Mattermax revision on top of that version. Releases are named `{version}-{revision}`, for example `12.0.1-1`.
- `patches/series`: the order the patches in `patches/` are applied in.
- `branding/`: `rebrand.py`, its `rules.json` (replacements and scope), `allowlist.json` (occurrences kept on purpose), the reviewed `files.list`, and `assets/` (replacement logos and icons). See `branding/README.md`.
- `config/overlay.json`: Mattermax settings merged into the packaged `config.json`.

## Adding a new patch

1. **Create a workspace.** `just workspace` clones the mirror at the pinned tag into `work/src`, tags the upstream commit `mattermax-base`, and applies every patch in `series` as its own commit.
2. **Develop.** Branch locally in `work/src`, write the code and run its tests. To try the branded product, run `just build`: it brands a separate copy in `work/build`, so the workspace stays unbranded.
3. **Commit.** One commit per patch. End the commit message with a trailer saying where the patch file goes:

   ```
   Feature message

   Mattermax-Patch: feature.patch
   ```
4. **Export.** `just export` writes every commit after `mattermax-base` to `patches/` with `git format-patch --zero-commit --no-signature`, and rewrites `series` in commit order. A re-exported patch is byte-identical when its code hasn't changed.
5. **Document.** Add a `### feature.patch` entry to `MODIFICATIONS.md`. For a feature Mattermost sells, state in the pull request that it was written without consulting Mattermost's enterprise code.
6. **Check.** `just check` confirms `series` matches the patch files, every patch has its trailer and a `MODIFICATIONS.md` entry and leaves `server/enterprise/`, `LICENSE.txt` and `NOTICE.txt` alone, and the whole series applies to a clean upstream tag.
7. **Open a pull request.** CI runs `just ci`: check, workspace and build (branding, the i18n check, the enterprise check and packaging).
8. **Clean up** after merging with `just clean`. The patch file is now the source of truth.

## Changing an existing patch

Change the commit, never the `.patch` file, then export again.

1. `just workspace`, then make the fix in `work/src`.
2. `git commit --fixup=<commit of that patch>`.
3. `git rebase -i --autosquash mattermax-base` folds the fix into the patch's commit.
4. `just export`, and update `MODIFICATIONS.md` if the behaviour changed.
5. `just check`, then open a pull request. Its diff shows exactly how the patch changed.

**Reordering:** change the commit order with `git rebase -i mattermax-base`, then `just export`.

**Disabling temporarily:** comment the patch out in `patches/series` with `# `; `just export` keeps disabled entries. A release that ships without a patch names it in the release notes.

**Removing:** drop the commit (`git rebase -i mattermax-base`) and `just export`; the patch file is removed. Note the removal in `MODIFICATIONS.md`.

## Changing branding or settings

Branding and settings are edited directly in this repo; they never become patches.

- **Text:** edit `branding/rules.json` (what is replaced, and in which files) or `branding/allowlist.json` (occurrences kept on purpose, each with a reason). Then run `just branding-files` and review the diff of `branding/files.list`.
- **Icons:** put the replacement in `branding/assets/` at the same path it has upstream, with the same format and, for PNGs, the same pixel size.
- **Settings:** edit `config/overlay.json`. Every key must already exist upstream, or the build fails.
- **Prefer settings to patches.** If Mattermost has a setting for a change, put it in the overlay instead of writing a patch.

Run `just build` and review `branding/report.md` (every rule and allowlist count, the icons still showing the upstream logo, and every file changed) and the packaged `work/build/dist/mattermax/config/config.json`. Open a pull request either way.

## Releasing

A release is a tag on this repo; CI builds and publishes everything from it.

1. Bump `revision` for any change between upstream releases (`12.0.1-1` becomes `12.0.1-2`) and merge.
2. Run `just tag`. It runs `just check`, refuses if there are uncommitted changes, and creates the tag `{version}-{revision}` locally.
3. Push the tag: `git push origin 12.0.1-2`. Pushing is a separate, deliberate step.
4. CI checks the tag matches `upstream.json` and `revision`, builds, and attaches to the release: the server tarball, a source tarball of the branded tree (with this repo under `mattermax/`) and its sha256 checksum. It pushes the Docker image to `ghcr.io/opnlabs/mattermax` with the same tag and `latest` (`.github/workflows/release.yml`).
5. Deploy by setting `mattermax_version` in the Nomad job to the new tag.

**Dev builds.** Run the Dev Build workflow from the Actions tab (on `main` or any branch). It builds the same way, with the release name `{version}-{revision}-dev.<commit>`, and pushes the image as `dev` and `dev-<commit>`. It makes no GitHub release.

The source tarball is the AGPL source offer; the About dialog in the product links to its release page.

## Upgrading to a new upstream release

An upgrade is one pull request: pin the new version, make every patch apply again, refresh branding, and release.

1. **Mirror.** A workflow in `mattermax-source` itself keeps it up to date with upstream. Check that the new release tag is there before pinning it.
2. **Pin.** On a branch, update `upstream.json` with the new version and its full commit hash (`git ls-remote https://github.com/opnlabs/mattermax-source refs/tags/vX.Y.Z`), and reset `revision` to `1`.
3. **Re-apply.** `just clean`, then `just workspace`. When a patch fails, fix the conflict in `work/src`, `git add` the files, run `git am --continue`, and carry on. Then `just export` to save the fixed patches.
4. **Triage.** Every patch should apply. A patch that can't be fixed in time and that the release can do without (a feature, not a license, attribution or security fix) is commented out in `series` and named in the release notes.
5. **Branding.** `just branding-files` regenerates `branding/files.list`. Review its diff and, after `just build`, the change in `branding/report.md`: new strings, new functional uses of the name that need an allowlist entry (user agents, headers, stored IDs), new upsell screens, and icons that moved.
6. **License and settings.** Diff `LICENSE.txt` between the old and new upstream tags; if it changed, stop and escalate to a maintainer. The build fails if an overlay key no longer exists upstream.
7. **Release.** Run `just ci`, merge, then `just tag` and push the tag (`{version}-1`).

## Rules

- **Never commit to `mattermax-source`.** All changes to upstream code are patch files in this repo.
- **Never edit a `.patch` file by hand.** Change the commit in a workspace and run `just export`.
- **Never let branding into a patch.** Don't run the rebrand script in `work/src`; `just build` brands a separate copy. Patches are written against the unbranded tree.
- **One concern per patch,** with the smallest possible change to upstream files. Prefer adding new files through Mattermost's extension points over editing existing ones, and an early-return guard over deleting code. When code must go, delete the lines rather than commenting them out.
- **Never use or consult Mattermost's enterprise code** (`server/enterprise/` or the private enterprise repo), and never build with the `enterprise` or `sourceavailable` tags. Ignore the enterprise-linking steps in upstream's `.cursor/` and `enable-claude-docs.sh`.

## Command reference

| Command | What it does | Script |
| --- | --- | --- |
| `just` | Lists all recipes | (built in) |
| `just workspace` | Clones the mirror at the pinned tag into `work/src` and applies every patch as a commit | `create-workspace.sh` |
| `just export` | Writes commits after `mattermax-base` to `patches/` and rewrites `series` | `export-patches.sh` |
| `just check` | Checks `series` against the patch files and applies the whole series to a clean upstream tag | `check-patches.sh` |
| `just branding-files` | Regenerates `branding/files.list` from `work/src` | `update-branding-files.sh` |
| `just build` | Copies the workspace to `work/build`, brands it, builds, and packages with the settings overlay | `build-release.sh` |
| `just ci` | Everything a pull request runs: check, workspace, build | (calls the above) |
| `just tag` | Runs `check`, refuses with uncommitted changes, and tags `{version}-{revision}` locally | (inline) |
| `just clean` | Deletes `work/src` and `work/build` only (the upstream cache in `work/upstream.git` stays) | (inline) |
