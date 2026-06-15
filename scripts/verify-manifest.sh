#!/usr/bin/env bash
# Verify that bumping a managed package to its manifest `version` builds cleanly.
# This is the PR gate ("full packaging check"). Run as root in the Arch container.
# Usage: verify-manifest.sh <manifest>
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

manifest="$(realpath -- "$1")"
name="$(manifest_get "$manifest" name)"
target="$(manifest_get "$manifest" version)"
log "verifying $name -> $target"

dir="$("$LIBDIR/clone-aur.sh" "$manifest" read)"
chown -R builder "$dir" 2>/dev/null || true
runuser -u builder -- "$LIBDIR/apply-bump.sh" "$manifest" "$dir" "$target"
runuser -u builder -- "$LIBDIR/srcinfo-check.sh" "$dir"
runuser -u builder -- env "MAKEPKG_DEPS=${MAKEPKG_DEPS:-1}" "$LIBDIR/build-check.sh" "$dir"
log "verified $name $target OK"
