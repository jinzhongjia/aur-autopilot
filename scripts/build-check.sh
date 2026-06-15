#!/usr/bin/env bash
# Full packaging check: namcap the recipe, build with makepkg, namcap the built
# package. Run as the `builder` user. Usage: build-check.sh <workdir>
#
# Gates (fatal): makepkg must build successfully; namcap must report no errors
# (E:) on the PKGBUILD. namcap warnings and built-package findings are advisory
# (printed, non-fatal) because benign warnings are common across the AUR.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

workdir="$(realpath -- "$1")"
cd "$workdir"

log "namcap PKGBUILD"
pkgbuild_namcap="$(namcap PKGBUILD 2>&1 || true)"
printf '%s\n' "$pkgbuild_namcap" >&2
if printf '%s\n' "$pkgbuild_namcap" | grep -q ' E: '; then
  die "namcap reported errors (E:) on PKGBUILD"
fi

# Default: install make/runtime deps via pacman (a true build check). Set
# MAKEPKG_DEPS=0 to skip dep installation (useful for local validation of -bin
# packages that only repackage a binary and don't compile).
deps_flag="--syncdeps"
[ "${MAKEPKG_DEPS:-1}" = "0" ] && deps_flag="--nodeps"

log "building (makepkg $deps_flag)"
makepkg "$deps_flag" --noconfirm --noprogressbar --needed --force

shopt -s nullglob
built=( *.pkg.tar.* )
[ "${#built[@]}" -gt 0 ] || die "build produced no package artifact"

log "namcap built package(s): ${built[*]}"
namcap "${built[@]}" >&2 || true   # advisory

log "build check passed: ${built[*]}"
