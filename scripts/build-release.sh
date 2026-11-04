#!/usr/bin/env bash
# Copy the workspace to work/build/src, brand it, write the source tarball,
# build the server and web app, and package them with the settings overlay.
#
# Output, in work/build/dist:
#   mattermax-<release>-linux-amd64.tar.gz    server package
#   mattermax-<release>-source.tar.gz(.sha256) AGPL source offer
#   mattermax/                                 the unpacked server package
source "$(dirname "$0")/lib.sh"

[[ -d "$SRC/.git" ]] || die "no workspace; run 'just workspace' first"

out="$BUILD/src"
dist="$BUILD/dist"
name="mattermax-$RELEASE"

# copy_files GIT_DIR DEST: copy tracked and untracked (not ignored) files, so
# uncommitted work in the workspace is included but its build output isn't.
# server/enterprise/ is never copied: it isn't built, branded or shipped in the
# source tarball, and any import of it fails to compile.
copy_files() {
  mkdir -p "$2"
  local deleted
  deleted="$(git -C "$1" ls-files -d)"
  git -C "$1" ls-files -co --exclude-standard |
    { if [[ -n "$deleted" ]]; then grep -vxF -e "$deleted"; else cat; fi; } |
    { grep -v '^server/enterprise/' || (( $? == 1 )); } |
    tar -C "$1" -cf - --no-recursion -T - | tar -C "$2" -xf -
}

# absent PATTERN FILE: succeed if the extended regex PATTERN doesn't match FILE.
# A grep error is fatal, never read as "no match".
absent() {
  local rc=0
  grep -qE -- "$1" "$2" || rc=$?
  case "$rc" in
    0) return 1 ;;
    1) return 0 ;;
    *) die "grep failed on $2" ;;
  esac
}

# The build hash (About dialog, logs, the web app's "new version" prompt) is
# the Mattermax commit; upstream's commit is pinned in upstream.json.
hash="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)" || hash=unknown
[[ -z "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]] || hash="$hash-dirty"

log "Copying work/src to work/build/src"
rm -rf -- "$BUILD"
mkdir -p "$dist"
copy_files "$SRC" "$out"
[[ ! -e "$out/server/enterprise" ]] || die "server/enterprise/ was copied into the build tree"

log "Branding"
python3 -I "$ROOT/branding/rebrand.py" apply "$out" --report "$ROOT/branding/report.md"

# The source offer: the branded tree, plus this repo (patches, branding,
# overlay and build scripts) under mattermax/ so the build can be reproduced.
copy_files "$ROOT" "$out/mattermax"
log "Writing $name-source.tar.gz"
epoch="$(git -C "$SRC" log -1 --format=%ct)"
tar -C "$BUILD" --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$epoch" \
  --transform "s,^src,$name," -cf - src | gzip -n > "$dist/$name-source.tar.gz"
(cd "$dist" && sha256sum "$name-source.tar.gz" > "$name-source.tar.gz.sha256")

log "Building server and web app ($RELEASE, $hash)"
# Team Edition only: no enterprise directory, and a BUILD_NUMBER other than
# "dev" so the sourceavailable tag is never added. No prepackaged plugins:
# those are downloaded from Mattermost. CI=true makes the webapp install with
# `npm ci`, exactly from the lockfile, instead of `npm install`.
# cd rather than make -C: upstream's Makefile builds paths from $(PWD) (GOBIN,
# the packaged config.json), which make -C doesn't change.
(cd "$out/server" && make build-client build-linux-amd64 package-linux-amd64 \
  CI=true \
  BUILD_NUMBER="$RELEASE" \
  BUILD_HASH="$hash" \
  BUILD_ENTERPRISE=false \
  BUILD_ENTERPRISE_DIR=/nonexistent \
  PLUGIN_PACKAGES=)

log "Checking the binaries have no enterprise code"
# Every packaged executable is checked. The tool output goes to files and is
# searched only after the tool succeeded: piping it into grep -q can hide a
# match (SIGPIPE under pipefail) or a tool failure.
for bin in "$out/server/bin/mattermost" "$out/server/bin/mmctl"; do
  go version -m "$bin" > "$BUILD/buildinfo.txt" || die "can't read the build info of $bin"
  go tool nm "$bin" > "$BUILD/symbols.txt" || die "can't list the symbols of $bin"
  absent '-tags=.*\b(enterprise|sourceavailable)\b' "$BUILD/buildinfo.txt" ||
    die "$bin was built with an enterprise or sourceavailable tag"
  absent 'server/v8/enterprise' "$BUILD/symbols.txt" ||
    die "$bin contains server/v8/enterprise symbols"
done

log "Checking en.json matches the branded source strings"
(cd "$out/webapp/channels" && npm run --silent i18n-extract:check)

log "Packaging with config/overlay.json"
tar -C "$dist" -xzf "$out/server/dist/mattermost-team-linux-amd64.tar.gz"
mv "$dist/mattermost" "$dist/mattermax"
# The server binary ships as mattermax; mmctl keeps its name. Go builds it as
# "mattermost" (from server/cmd/mattermost), and nothing depends on the name.
mv "$dist/mattermax/bin/mattermost" "$dist/mattermax/bin/mattermax"
python3 -I "$ROOT/scripts/merge-config.py" "$dist/mattermax/config/config.json" "$ROOT/config/overlay.json"
chmod 600 "$dist/mattermax/config/config.json"
tar -C "$dist" --owner=0 --group=0 --numeric-owner -czf "$dist/$name-linux-amd64.tar.gz" mattermax

log "Done: $dist"
ls -l "$dist" >&2
