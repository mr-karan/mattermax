#!/usr/bin/env bash
# Clone the pinned upstream into work/src and apply every patch in series as
# its own commit. On a conflict, fix it in work/src and run `git am --continue`.
source "$(dirname "$0")/lib.sh"

[[ -e "$SRC" ]] && die "$SRC already exists; run 'just clean' first"

log "Creating workspace at $SRC ($UPSTREAM_TAG, $COMMIT)"
new_tree "$SRC"

lines patches active_patches
if (( ${#patches[@]} == 0 )); then
  log "No patches in series; workspace is plain $UPSTREAM_TAG"
  exit 0
fi

log "Applying ${#patches[@]} patches"
if ! git -C "$SRC" am -q --3way --keep-cr "${patches[@]/#/$ROOT/patches/}"; then
  cat >&2 <<EOF

A patch did not apply. To carry on:
  cd work/src
  # resolve the conflicts, then
  git add <files> && git am --continue
When every patch is applied, run 'just export'.
EOF
  exit 1
fi
log "Workspace ready: branch 'mattermax', upstream tagged '$BASE_TAG'"
