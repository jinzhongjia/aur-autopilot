#!/usr/bin/env bash
# Build a validated candidate and open an "update available" issue.
# Run as root inside the Arch container. Requires GH_TOKEN + GH_REPO in env.
# Usage: open-update-issue.sh <manifest> <workdir> <current> <latest>
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

manifest_arg="$1"
manifest="$(realpath -- "$1")"; workdir="$(realpath -- "$2")"; current="$3"; latest="$4"
name="$(manifest_get "$manifest" name)"
tmp="${RUNNER_TEMP:-/tmp}"
diff="$tmp/${name}.diff"; blog="$tmp/${name}.pkg.log"; body="$tmp/${name}.issue.md"

chown -R builder "$workdir" 2>/dev/null || true

# Produce the validated, ready-to-apply file contents and the human diff.
runuser -u builder -- "$LIBDIR/apply-bump.sh" "$manifest" "$workdir" "$latest"
git -C "$workdir" --no-pager diff -- PKGBUILD .SRCINFO > "$diff" || true

# Full packaging check. Non-fatal here: we still file the issue, flagged on failure.
status=ok
: > "$blog"
if ! runuser -u builder -- "$LIBDIR/srcinfo-check.sh" "$workdir" >>"$blog" 2>&1; then status=failed; fi
if [ "$status" = "ok" ] && ! runuser -u builder -- env "MAKEPKG_DEPS=${MAKEPKG_DEPS:-1}" "$LIBDIR/build-check.sh" "$workdir" >>"$blog" 2>&1; then status=failed; fi

MANIFEST_PATH="$manifest_arg" "$LIBDIR/render-issue.sh" "$name" "$current" "$latest" "$diff" "$blog" "$status" > "$body"

label="update-available"
[ "$status" = "failed" ] && label="update-available,build-failed"
url="$(gh issue create --title "Update available: $name $latest" --body-file "$body" --label "$label")"
log "opened issue: $url (status=$status)"
