# Branding

`rebrand.py` renames Mattermost to Mattermax across the server and web app at
build time. It runs on the copy in `work/build/src`, never on `work/src`, so
patches are always written against the unbranded tree.

## Text

`rules.json` says which files are in scope (`include`/`exclude`) and what is
replaced (`replace`, applied in order; the first rule that matches at a
position wins). Two narrow rules also rename the CLI's own name in
`server/cmd/mattermost/commands` (`Use: "mattermax"` and `$ mattermax db ...`
examples), to match the packaged binary. Otherwise matching is by whole word,
so identifiers such as
`MattermostPlugin`, Go module paths, npm package names, lowercase `mattermost`
(binaries, URLs, the desktop URL scheme) and i18n message IDs are never
touched. Source `defaultMessage` strings, `en.json` and the other locales are
renamed by the same rules, so they stay in sync and upstream's
`i18n-extract:check` still passes.

`allowlist.json` lists occurrences that are kept on purpose, each with a
reason: Mattermost the company (copyright headers), its commercial editions,
legal documents, services and plugins, the official desktop app, and strings
that other software depends on (user-agent detection, HTTP header names,
stored theme IDs). An occurrence is kept when it falls inside a match of an
entry that applies to the file.

`files.list` is the reviewed list of files the rules change. The build fails
when it is out of date, so new upstream strings always get a look: run
`just branding-files` and review the diff.

## Icons

Put a replacement file in `assets/` at the same path it has upstream, for
example `assets/webapp/channels/src/images/favicon/favicon-16x16.png`. It must
keep the upstream file's format and, for PNGs, its pixel size, so no code
that references it needs to change. Inline SVG logo components (`.tsx`) are
replaced the same way; keep the component's name and exports.

The `icons` list in `rules.json` names the upstream files that show the
Mattermost logo; `report.md` lists the ones not yet replaced.

### Artwork

All 38 logo files are replaced: the speech-bubble "M" mark, and the lockup of
the mark plus the "mattermax" wordmark. The vector masters live with the
designer, not in this repo. The wordmark is Manrope ExtraBold (SIL Open Font
License) converted to outlines, so no font ships in the product.

| Colour | Hex | Use |
| --- | --- | --- |
| Signal teal | `#0E7C6B` | Mark, "max", app tiles, unread dot |
| Deep ink | `#10201F` | "matter", dark logos, header logo |
| Mint | `#7FE0C9` | Accent |
| Grey | `#5F6F6C` | Small grey email logo |
| Mention red | `#D24B4E` | Mentions dot on the favicon |

Favicon states: `default` is the mark, `unread` adds a teal dot, `mentions` a
red dot. Favicons of 32 px and under use a thicker "M" so it reads at 16 px.

## Report

`just build` writes `report.md`: counts per rule and allowlist entry, the
assets replaced, the icons still upstream, and every file changed. Commit it
with branding changes so its diff can be reviewed.
