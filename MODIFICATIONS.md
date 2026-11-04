# Modifications

Mattermax is a modified version of [Mattermost](https://github.com/mattermost/mattermost),
licensed under the GNU AGPL v3.0. As section 5(a) of the AGPL requires, this file
records every change made to the upstream source, with its date.

The changes come in three kinds:

- **Patches** in `patches/`, applied in the order of `patches/series`. Each one
  has an entry below.
- **Branding**, applied at build time by `branding/rebrand.py`: the product name
  "Mattermost" is replaced with "Mattermax" in user-visible text, following
  `branding/rules.json` and `branding/allowlist.json`, and logos and icons are
  replaced with the files in `branding/assets/`. Each release's
  `branding/report.md` lists every file changed.
- **Default settings** in `config/overlay.json`, merged into the packaged
  `config.json`.

## Patches

Format: `### <name>.patch`, then the date it
was added or last changed in behaviour, and what it does and why. When a patch
is removed (for example because upstream merged it), keep its entry and add the
removal date.

### release-license.patch

2026-11-03. `server/build/release.mk` packages `LICENSE.txt` (AGPL v3.0) with
the server instead of `MIT-COMPILED-LICENSE.md`. Upstream's MIT compiled
license covers only binaries produced by Mattermost, Inc.; Mattermax builds
its own, which `LICENSE.txt` places under the AGPL.

### remove-user-limits.patch

2026-11-03. Removes the 200/250 active user limit on servers without a
Mattermost license (`server/channels/app/limits.go`).


### about-dialog.patch

2026-11-04. Show the product name without "Team Edition", replace the community link
with an attribution to Mattermost, add the AGPL notice with a link to the
running version's source code (AGPL section 13), and drop the links to
Mattermost's terms of use and privacy policy, which don't cover a
self-hosted Mattermax server.

### optional-policy-links.patch

2026-11-04. Clear a blank TermsOfServiceLink instead of resetting it to Mattermost's
terms, as upstream already does for PrivacyPolicyLink. Show the sign-up
agreement checkbox only when a policy link is configured, naming only the
links that are, and don't require it otherwise.
