#!/usr/bin/env bash
# Apply a version bump to a cloned package: set pkgver, reset pkgrel, recompute
# checksums, regenerate .SRCINFO. Deterministic; run as the `builder` user.
# Usage: apply-bump.sh <manifest.toml> <workdir> <target-version>
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

manifest="$(realpath -- "$1")"
workdir="$(realpath -- "$2")"
target="$3"
[ -n "$target" ] || die "target version required"
pkgrel="$(manifest_get_or "$manifest" pkgrel 1)"

cd "$workdir"
[ -f PKGBUILD ] || die "no PKGBUILD in $workdir"

# Bump version and reset pkgrel (handles quoted and unquoted assignments).
sed -i -E "s/^[[:space:]]*pkgver=.*/pkgver=${target}/" PKGBUILD
sed -i -E "s/^[[:space:]]*pkgrel=.*/pkgrel=${pkgrel}/" PKGBUILD

got="$(pkgbuild_pkgver .)"
[ "$got" = "$target" ] || die "failed to set pkgver (PKGBUILD reports '$got'); does this package compute pkgver dynamically?"

log "recomputing checksums (updpkgsums)"
updpkgsums

log "regenerating .SRCINFO"
makepkg --printsrcinfo > .SRCINFO

log "applied bump: pkgver=$target pkgrel=$pkgrel"
