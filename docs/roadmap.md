# Roadmap

Mattermost already has most of what Slack and Discord offer. Mattermax adds the
rest as small patches instead of building a new chat app. This page lists the
candidates, grouped by how much work each is. Each item links to its issue,
where the details and the progress live.

## Tier 1: unlock what is already built

These features are fully implemented in AGPL code in the upstream tree. Team
Edition turns them off with a license check, the same way it limited users
before `remove-user-limits.patch`. Each patch removes the checks in AGPL files
only and never touches `server/enterprise/`. Each is one PR in a stack, so a
maintainer can accept or drop one without the others.

| Feature | Slack or Discord equivalent | Issue |
| --- | --- | --- |
| Scheduled messages and acknowledgements | Schedule send, ack on urgent posts | [opnlabs#1](https://github.com/opnlabs/mattermax/issues/1) |
| Custom user groups | `@group` mentions, Discord role pings | [opnlabs#2](https://github.com/opnlabs/mattermax/issues/2) |
| Permission schemes and channel moderation | Read-only channels, per-channel overrides | [opnlabs#3](https://github.com/opnlabs/mattermax/issues/3) |
| Guest accounts and magic links | Slack guests | [opnlabs#4](https://github.com/opnlabs/mattermax/issues/4) |
| Shared channels between servers | Slack Connect | [opnlabs#5](https://github.com/opnlabs/mattermax/issues/5) |
| Announcement banners | Workspace-wide notices | [opnlabs#6](https://github.com/opnlabs/mattermax/issues/6) |

## Tier 2: write paid features from scratch

Mattermost sells these and keeps their implementation in enterprise code.
Mattermax writes them without consulting that code, as `AGENTS.md` requires,
usually by implementing an interface in `server/einterfaces/`.

| Feature | Why | Issue |
| --- | --- | --- |
| Data retention policies | Delete old messages and files, globally or per channel | [#7](https://github.com/mr-karan/mattermax/issues/7) |
| Message translation | Through a local service, so no message leaves the network | [#8](https://github.com/mr-karan/mattermax/issues/8) |
| Catch-up summaries | Through a local LLM, with a per-channel opt-out | [#9](https://github.com/mr-karan/mattermax/issues/9) |

## Tier 3: features Mattermost does not have

| Feature | Slack or Discord equivalent | Issue |
| --- | --- | --- |
| Voice messages and clips | Slack clips, Discord voice messages | [#10](https://github.com/mr-karan/mattermax/issues/10) |
| Opt-in read receipts | Neither has them | [#11](https://github.com/mr-karan/mattermax/issues/11) |
| Slowmode, thread auto-archive, command palette, quote reply | Discord slowmode and archiving, Slack quick switcher | [#12](https://github.com/mr-karan/mattermax/issues/12) |
| Drop-in voice rooms, as a separate plugin | Slack Huddles, Discord voice channels | [#13](https://github.com/mr-karan/mattermax/issues/13) |

## Beyond Slack and Discord

Ideas that only a self-hosted server can credibly offer: encrypted channels
with local search, AI that never leaves the network, signed messages, channel
docs stored in Git, and link-only incident rooms. See
[#14](https://github.com/mr-karan/mattermax/issues/14).

## Not planned

- **Polls.** The matterpoll plugin already does this well.
- **Lists and kanban.** Boards covers it.
- **Discord forum channels and its full role system.** Both change core
  assumptions and would conflict on every upgrade. Custom groups and permission
  schemes cover most of the need.
- **SAML and LDAP.** OpenID Connect sign-in lets Keycloak or Authentik bridge
  to both.
- **Patching the Calls plugin.** Its group calls are under `LICENSE.enterprise`.
