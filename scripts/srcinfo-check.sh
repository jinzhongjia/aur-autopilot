#!/usr/bin/env bash
# Fail if .SRCINFO is out of sync with PKGBUILD. Run as the `builder` user.
# Usage: srcinfo-check.sh <workdir>
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

workdir="$(realpath -- "$1")"
cd "$workdir"
[ -f .SRCINFO ] || die "no .SRCINFO present"

makepkg --printsrcinfo > .SRCINFO.expected
if ! diff -u .SRCINFO .SRCINFO.expected; then
  rm -f .SRCINFO.expected
  die ".SRCINFO is out of sync with PKGBUILD (run: makepkg --printsrcinfo > .SRCINFO)"
fi
rm -f .SRCINFO.expected
log ".SRCINFO in sync with PKGBUILD"
