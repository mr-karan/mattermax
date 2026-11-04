#!/usr/bin/env bash
# Write every commit after mattermax-base in work/src to patches/, at the path
# named by its "Mattermax-Patch:" trailer, and rewrite patches/series in
# commit order. Disabled entries in series are kept.
source "$(dirname "$0")/lib.sh"

[[ -d "$SRC/.git" ]] || die "no workspace; run 'just workspace' first"
git -C "$SRC" rev-parse -q --verify "refs/tags/$BASE_TAG" >/dev/null || die "work/src has no '$BASE_TAG' tag"
[[ -z "$(git -C "$SRC" status --porcelain)" ]] || die "work/src has uncommitted changes; commit them first"
[[ ! -d "$SRC/.git/rebase-apply" && ! -d "$SRC/.git/rebase-merge" ]] || die "a 'git am' or rebase is in progress in work/src"
[[ -z "$(git -C "$SRC" rev-list --merges "$BASE_TAG..HEAD")" ]] || die "merge commits can't be exported; rebase onto $BASE_TAG"

lines commits git -C "$SRC" rev-list --reverse "$BASE_TAG..HEAD"

declare -A seen=()
paths=()
for c in "${commits[@]}"; do
  subject="$(git -C "$SRC" log -1 --format=%s "$c")"
  lines trailer git -C "$SRC" log -1 --format='%(trailers:key=Mattermax-Patch,valueonly,separator=%x0A)' "$c"
  (( ${#trailer[@]} == 1 )) || die "commit ${c:0:12} '$subject' needs exactly one 'Mattermax-Patch: <name>.patch' trailer"
  p="${trailer[0]}"
  [[ "$p" =~ ^[a-z0-9][a-z0-9._-]*\.patch$ ]] || die "commit ${c:0:12}: bad patch path '$p'"
  [[ -z "${seen[$p]:-}" ]] || die "two commits export to $p"
  seen[$p]=1
  paths+=("$p")
done

# Patches disabled in series have no commit; keep them disabled.
disabled=()
lines commented grep -E '^# [^/]*\.patch$' "$ROOT/patches/series" || true
for line in "${commented[@]}"; do
  p="${line#\# }"
  if [[ -f "$ROOT/patches/$p" && -z "${seen[$p]:-}" ]]; then disabled+=("$p"); fi
done

# Remove patch files that are no longer produced by any commit (dropped or
# renamed patches). They stay in git history.
lines old active_patches
for p in "${old[@]}"; do
  if [[ -z "${seen[$p]:-}" && -f "$ROOT/patches/$p" ]]; then
    log "Removing patches/$p (no commit exports to it any more)"
    rm -- "$ROOT/patches/$p"
  fi
done

for i in "${!commits[@]}"; do
  git -C "$SRC" format-patch -1 --stdout --zero-commit --no-signature \
    --no-numbered --no-cover-letter --no-thread --no-notes --no-color \
    --encoding=UTF-8 "${commits[$i]}" > "$ROOT/patches/${paths[$i]}"
done

{
  echo '# Patch apply order. Written by `just export`; edit by hand only to disable'
  echo '# a patch by commenting it out with "# ".'
  for p in "${paths[@]}"; do printf '%s\n' "$p"; done
  for p in "${disabled[@]}"; do printf '# %s\n' "$p"; done
} > "$ROOT/patches/series.new"
mv "$ROOT/patches/series.new" "$ROOT/patches/series"

log "Exported ${#paths[@]} patches; ${#disabled[@]} disabled entries kept"
git -C "$ROOT" status --short -- patches/ >&2 || true
