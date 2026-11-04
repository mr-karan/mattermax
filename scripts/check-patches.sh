#!/usr/bin/env bash
# Check that patches/series matches the patch files and that the whole series
# applies, without conflicts, to a clean checkout of the pinned upstream tag.
source "$(dirname "$0")/lib.sh"

fail=0
problem() { printf 'error: %s\n' "$*" >&2; fail=1; }

# --- series <-> files ------------------------------------------------------
declare -A listed=()
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  if [[ "$line" =~ ^#\ ([^/]*\.patch)$ ]]; then
    p="${BASH_REMATCH[1]}"
  elif [[ "$line" == \#* ]]; then
    continue
  else
    p="$line"
  fi
  [[ "$p" =~ ^[a-z0-9][a-z0-9._-]*\.patch$ ]] || { problem "series: bad entry '$line'"; continue; }
  [[ -z "${listed[$p]:-}" ]] || problem "series: $p is listed twice"
  listed[$p]=1
  [[ -f "$ROOT/patches/$p" ]] || problem "series: $p is listed but patches/$p does not exist"
done < "$ROOT/patches/series"

lines files find "$ROOT/patches" -name '*.patch' -type f
for f in "${files[@]}"; do
  p="${f#"$ROOT/patches/"}"
  [[ -n "${listed[$p]:-}" ]] || problem "patches/$p is not in series"
done

# --- per-patch rules -------------------------------------------------------
for p in "${!listed[@]}"; do
  f="$ROOT/patches/$p"
  [[ -f "$f" ]] || continue
  grep -qxF "Mattermax-Patch: $p" "$f" || problem "$p: commit message lacks 'Mattermax-Patch: $p' (re-export with 'just export')"
  grep -qF "### $p" "$ROOT/MODIFICATIONS.md" || problem "$p: no entry in MODIFICATIONS.md"
  if grep -qE '^diff --git a/(server/enterprise/|LICENSE\.txt|LICENSE\.enterprise|NOTICE\.txt)' "$f"; then
    problem "$p: touches server/enterprise/, LICENSE.txt, LICENSE.enterprise or NOTICE.txt"
  fi
done

(( fail == 0 )) || die "series check failed"
log "series matches ${#listed[@]} patch files"

# --- apply to a clean tree -------------------------------------------------
lines patches active_patches
(( ${#patches[@]} > 0 )) || { log "no active patches; nothing to apply"; exit 0; }

# Apply to a scratch index of the pinned commit: no checkout, so it takes
# seconds. No --3way: every patch must apply as written.
ensure_cache
export GIT_INDEX_FILE="$WORK/check.index"
git --git-dir="$CACHE" read-tree "$COMMIT"
log "Applying ${#patches[@]} patches to a clean $UPSTREAM_TAG"
for p in "${patches[@]}"; do
  git --git-dir="$CACHE" apply --cached "$ROOT/patches/$p" || die "$p does not apply cleanly on top of the patches before it"
done
log "all patches apply cleanly"
