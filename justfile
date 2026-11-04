# Mattermax patch repo. Run `just` to list recipes; see docs/workflow.md.

set shell := ["bash", "-euo", "pipefail", "-c"]

# List all recipes
default:
    @{{just_executable()}} --list --unsorted

# Clone the pinned upstream into work/src and apply every patch as a commit
workspace:
    scripts/create-workspace.sh

# Write commits after mattermax-base to patches/ and rewrite series
export:
    scripts/export-patches.sh

# Apply the whole series to a clean upstream tag and check series matches the patch files
check:
    scripts/check-patches.sh

# Regenerate branding/files.list from work/src
branding-files:
    scripts/update-branding-files.sh

# Brand a copy of work/src in work/build, apply the settings overlay, and build
build:
    scripts/build-release.sh

# Everything a pull request runs: check, workspace, build
ci: check workspace build

# Run check, refuse with uncommitted changes, and tag {version}-{revision} locally
tag: check
    #!/usr/bin/env bash
    source scripts/lib.sh
    [[ -z "$(git status --porcelain)" ]] || die "uncommitted changes; commit or stash them first"
    git rev-parse -q --verify "refs/tags/$RELEASE" >/dev/null && die "tag $RELEASE already exists; bump 'revision'"
    git tag -a "$RELEASE" -m "Mattermax $RELEASE"
    log "Tagged $RELEASE. Push it with: git push origin $RELEASE"

# Delete work/src and work/build only
clean:
    rm -rf work/src work/build
