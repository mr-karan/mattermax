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

### openid-connect.patch

2026-11-04. Sign in with any OpenID Connect provider without a license. A new
provider (`server/channels/app/oauthproviders/openid/`) finds the provider's
endpoints from `OpenIdSettings.DiscoveryEndpoint` and reads the user from the
UserInfo endpoint; it is registered in `server/cmd/mattermost/main.go`.
Discovery uses the server's outgoing HTTP client, so internal addresses must
be in `AllowedUntrustedInternalConnections`, and doesn't follow redirects.
Every login requires an ID token from the token endpoint whose issuer,
audience, authorized party and expiry are valid, and whose subject matches the
UserInfo response. The provider must mark the email address verified
(`email_verified` true). Accounts are identified by a hash of issuer and
subject, so a different provider never signs in to an existing account. The
client config sends the OpenID login button settings without a license
(`server/config/client.go`), and the System Console shows the OpenID Connect
page instead of its upgrade page, offering only "OpenID Connect (Other)"
(`admin_definition.tsx`). Written from the OpenID Connect specifications and
Mattermost's open-source OAuth code, without consulting Mattermost's
enterprise code.

### remove-upsell-pages.patch

2026-11-04. Remove the System Console pages that only advertise paid
Mattermost features: every feature discovery page and the About > Edition and
License page (`remove_upsell_pages.ts`, applied in
`selectors/admin_console.tsx` before plugins change the console). Sections
for unlicensed paid features inside other pages, such as Burn-on-Read
messages, show nothing instead of an upgrade prompt
(`licensed_section_container.tsx`). Mattermax has no license to show, and
these features are not in its build.

### fix-mfa-switch-title.patch

2026-11-04. Fix the title of the MFA step when switching an email/password
account to SSO, which showed a literal "{uiType}" instead of the sign-in
method (`email_to_oauth.tsx`). Upstream formatted the message without its
value.

### no-enterprise-imports.patch

2026-11-04. Remove every import of `server/enterprise/` that isn't behind the
`enterprise` build tag, so Mattermax builds without that tree. The server no
longer imports the enterprise package (`server/cmd/mattermost/main.go`).
mmctl drops its `compliance-export` command, its tests and its docs: the
command used enterprise job settings, and Team Edition has no compliance
export jobs. The enterprise metrics test (`server/channels/app/metrics_test.go`)
is removed.

### id-loaded-push-notifications.patch

2026-11-04. Allow "Full message content fetched from the server on receipt"
(`EmailSettings.PushNotificationContents` = `id_loaded`) without a license.
Push notifications then carry only IDs, and the mobile app fetches the message
from the server through `/api/v4/notifications/ack`, so the push proxy, Apple
and Google never see message contents. A new implementation of upstream's
`NotificationInterface` (`server/channels/app/notification_id_loaded.go`)
registers itself through `RegisterNotificationInterface` and builds the
fetched message with the same code as the "full" setting. The System Console
offers the option without a license (`admin_definition.tsx`). Written from
Mattermost's open-source notification code, without consulting Mattermost's
enterprise code.
