# Shared helpers for the scripts in this directory. Source it; don't run it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/work"
SRC="$WORK/src"
BUILD="$WORK/build"
CACHE="$WORK/upstream.git"
BASE_TAG="mattermax-base"

log() { printf '==> %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# upstream_get KEY: read a value from upstream.json.
upstream_get() {
  python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' \
    "$ROOT/upstream.json" "$1"
}

VERSION="$(upstream_get version)"
COMMIT="$(upstream_get commit)"
UPSTREAM_REPO="$(upstream_get repo)"
UPSTREAM_TAG="v$VERSION"
REVISION="$(tr -d '[:space:]' < "$ROOT/revision")"
# MATTERMAX_RELEASE overrides the release name for dev builds; it becomes the
# package names and the server's BUILD_NUMBER.
RELEASE="${MATTERMAX_RELEASE:-$VERSION-$REVISION}"

[[ "$COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "upstream.json: commit must be a full 40-character hash"
[[ "$REVISION" =~ ^[1-9][0-9]*$ ]] || die "revision must be a positive integer"
# BUILD_NUMBER=dev makes upstream add the sourceavailable tag.
[[ "$RELEASE" =~ ^[0-9A-Za-z][0-9A-Za-z._-]*$ && "$RELEASE" != dev ]] || die "bad release name '$RELEASE'"

# lines NAME CMD...: run CMD and store its output lines in array NAME (empty
# output gives an empty array). Avoids process substitution, which needs
# /dev/fd.
lines() {
  local -n _lines="$1"; shift
  local out
  out="$("$@")"
  _lines=()
  if [[ -n "$out" ]]; then mapfile -t _lines <<< "$out"; fi
}

# Patch paths in series order. Disabled (commented-out) entries are skipped.
active_patches() {
  grep -vE '^[[:space:]]*(#|$)' "$ROOT/patches/series" || true
}

# Fetch the pinned tag into a local bare cache, once, and check that it still
# points at the commit in upstream.json.
ensure_cache() {
  if [[ ! -d "$CACHE" ]]; then
    git init -q --bare "$CACHE"
    git -C "$CACHE" remote add origin "$UPSTREAM_REPO"
  fi
  if ! git -C "$CACHE" rev-parse -q --verify "refs/tags/$UPSTREAM_TAG^{commit}" >/dev/null; then
    log "Fetching $UPSTREAM_TAG from $UPSTREAM_REPO"
    git -C "$CACHE" fetch -q --depth 1 origin "refs/tags/$UPSTREAM_TAG:refs/tags/$UPSTREAM_TAG"
  fi
  local got
  got="$(git -C "$CACHE" rev-parse "refs/tags/$UPSTREAM_TAG^{commit}")"
  [[ "$got" == "$COMMIT" ]] || die "$UPSTREAM_TAG is $got upstream, but upstream.json pins $COMMIT"
}

# new_tree DIR: create a git repo at DIR checked out at the pinned commit,
# tagged $BASE_TAG, on branch "mattermax".
new_tree() {
  local dir="$1"
  ensure_cache
  git init -q -b mattermax "$dir"
  git -C "$dir" fetch -q --depth 1 "$CACHE" "refs/tags/$UPSTREAM_TAG"
  git -C "$dir" reset -q --hard FETCH_HEAD
  git -C "$dir" tag "$BASE_TAG"
  # Settings that keep exported patches byte-identical across machines,
  # whatever the developer's global git config says.
  git -C "$dir" config core.abbrev 12
  git -C "$dir" config diff.noprefix false
  git -C "$dir" config diff.mnemonicPrefix false
  git -C "$dir" config diff.algorithm myers
  git -C "$dir" config diff.renames true
}
