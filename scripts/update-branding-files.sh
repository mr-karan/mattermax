#!/usr/bin/env bash
# Regenerate branding/files.list: the files the branding rules change in the
# pinned upstream plus patches (work/src). Read-only on work/src.
source "$(dirname "$0")/lib.sh"

[[ -d "$SRC/.git" ]] || die "no workspace; run 'just workspace' first"
python3 -I "$ROOT/branding/rebrand.py" list "$SRC"
git -C "$ROOT" diff --stat -- branding/files.list >&2 || true
