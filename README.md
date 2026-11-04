# Mattermax

Mattermax is a community-maintained, fully open source fork of
[Mattermost](https://github.com/mattermost/mattermost). It is not affiliated
with or endorsed by Mattermost, Inc.

Builds are Team Edition only and never include Mattermost's enterprise code.

## What's different

- **OpenID Connect sign-in** with any provider.
- **ID-only push notifications**: Apple and Google never see message contents, the app fetches them from your server.
- **No user limits** on unlicensed servers.
- **Private by default**: telemetry, Sentry, notices and the remote plugin marketplace are off.

Every change is listed in [MODIFICATIONS.md](MODIFICATIONS.md).

## Layout

Mattermax is a pinned upstream release plus:

- `patches/`: code changes, applied in `series` order.
- `branding/`: name and icon replacements, applied at build time.
- `config/overlay.json`: default settings.
- `scripts/`, `justfile`: workspace, export, check and build.
- `docker/`: image and Compose files.
- `upstream.json`, `revision`: the pinned version and Mattermax revision.

## Quick start

- [docs/development.md](docs/development.md): set up, build and run locally.
- [docs/workflow.md](docs/workflow.md): patches, branding, releases, upgrades.
- [AGENTS.md](AGENTS.md): rules for agents.

## License

The patches, scripts and other files in this repo are licensed under the
[GNU AGPL v3.0](LICENSE), as they modify AGPL-licensed Mattermost code.
Mattermost is a trademark of Mattermost, Inc.
