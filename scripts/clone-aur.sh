#!/usr/bin/env bash
# Clone a managed package's AUR repo into a work directory.
# Usage: clone-aur.sh <manifest.toml> [read|push]
# Prints the work directory path to stdout; all logs go to stderr.
#   read (default): anonymous HTTPS clone (detection / build-check)
#   push:           full SSH clone (publish; needs the AUR key in the env)
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

manifest="$(realpath -- "$1")"
mode="${2:-read}"
name="$(manifest_get "$manifest" name)"
[ -n "$name" ] || die "manifest $manifest has no 'name'"

base="${WORKDIR:-$(repo_root)/.work}"
dest="$base/$name"
rm -rf "$dest"
mkdir -p "$base"

case "$mode" in
  # AUR_READ_BASE lets you point detection/build-check at a mirror (or a local
  # file:// path for testing). Defaults to the AUR's anonymous HTTPS endpoint.
  read) url="${AUR_READ_BASE:-https://aur.archlinux.org}/${name}.git"; depth=(--depth 1) ;;
  push) url="ssh://aur@aur.archlinux.org/${name}.git"; depth=() ;;
  *) die "unknown clone mode: $mode" ;;
esac

log "cloning ($mode) $url -> $dest"
n=0
until git clone --quiet "${depth[@]}" "$url" "$dest"; do
  n=$((n + 1))
  [ "$n" -ge 3 ] && die "$name: git clone failed after $n attempts ($url)"
  log "clone attempt $n failed; retrying in 5s..."
  rm -rf "$dest"
  sleep 5
done
[ -f "$dest/PKGBUILD" ] || die "$name: cloned AUR repo has no PKGBUILD"

# Hand the tree to the build user when present (clone runs as root in CI).
if id builder >/dev/null 2>&1; then chown -R builder "$dest"; fi

printf '%s\n' "$dest"
