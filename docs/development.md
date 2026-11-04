# Local development

```sh
git clone https://github.com/opnlabs/mattermax.git && cd mattermax
just              # list the recipes
just workspace    # work/src: pinned upstream + every patch as a commit
```

`just workspace` keeps a cache of the upstream tag in `work/upstream.git`, so
later workspaces and `just check` don't download it again.

## Patch loop: work in `work/src`

Branch in `work/src` and use upstream's dev targets there.

> **Always pass `BUILD_NUMBER` to upstream's server targets.** Without it,
> upstream's Makefile sets `BUILD_NUMBER=dev`, which adds the
> `sourceavailable` build tag and compiles enterprise code. That is never
> allowed (see [AGENTS.md](../AGENTS.md)). Any value except `dev` works.

## Product loop: build and run Mattermax

```sh
just build
```

This copies `work/src` (including uncommitted changes) to `work/build/src`,
brands it, builds the web app and server, checks the binary for enterprise
code and `en.json` against the source, and packages it with
`config/overlay.json`. Output is in `work/build/dist/`:

- `mattermax/`: the unpacked package (`bin/mattermax`, `client/`, `config/`)
- `mattermax-<version>-<revision>-linux-amd64.tar.gz` and the source tarball
- `branding/report.md` in this repo is rewritten; review its diff

Start a throwaway database and run the package against it:

```sh
export MM_DB_PASSWORD='pick-a-local-password'
docker run -d --name mattermax-db \
  -e POSTGRES_USER=mmuser -e POSTGRES_PASSWORD="$MM_DB_PASSWORD" -e POSTGRES_DB=mattermax \
  -p 127.0.0.1:5432:5432 postgres:16

cd work/build/dist/mattermax
MM_SQLSETTINGS_DRIVERNAME=postgres \
MM_SQLSETTINGS_DATASOURCE="postgres://mmuser:${MM_DB_PASSWORD}@127.0.0.1:5432/mattermax?sslmode=disable&connect_timeout=10" \
MM_SERVICESETTINGS_SITEURL=http://localhost:8065 \
./bin/mattermax
```

Open http://localhost:8065; the first account you create is the system admin.
Settings set with `MM_*` variables are locked in the System Console. The
server writes to `config/config.json` in the package; rebuild for a clean one.
If the patch loop is running too, stop it first, since both use port 8065.

**To try the Docker image instead,** use `docker/docker-compose.dev.yml`. It
builds an image from `work/build/dist` and runs it with PostgreSQL:

```sh
cd docker
docker compose -f docker-compose.dev.yml up -d --build -V
```

`docker/docker-compose.yml` runs the published image
(`ghcr.io/opnlabs/mattermax:latest`, or `MATTERMAX_VERSION` from `.env`) the
same way.
