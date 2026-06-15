#!/usr/bin/env bash
# Detect whether a managed package has a newer upstream version.
# Usage: detect-update.sh <manifest.toml> <workdir>
# Outputs: name, current, latest, has_update (bool), regressed (bool).
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

manifest="$(realpath -- "$1")"
workdir="$(realpath -- "$2")"
name="$(manifest_get "$manifest" name)"
current="$(pkgbuild_pkgver "$workdir")"
[ -n "$current" ] || die "$name: could not read current pkgver from PKGBUILD"

cfg="$(mktemp --suffix=.toml)"
keyfile=""
cleanup() { rm -f "$cfg" "$keyfile"; }
trap cleanup EXIT

if manifest_has_nvchecker "$manifest"; then
  manifest_nvchecker_toml "$manifest" > "$cfg"
  log "using inline [nvchecker] override from manifest"
elif [ -f "$workdir/.nvchecker.toml" ]; then
  cat "$workdir/.nvchecker.toml" > "$cfg"
  log "using .nvchecker.toml shipped in the AUR repo"
else
  die "$name: no nvchecker config (no [nvchecker] in manifest, no .nvchecker.toml in AUR repo)"
fi

# Optional GitHub token to lift API rate limits for github/git sources.
if [ -n "${NV_GITHUB_TOKEN:-}" ]; then
  keyfile="$(mktemp --suffix=.toml)"
  printf '[keys]\ngithub = "%s"\n' "$NV_GITHUB_TOKEN" > "$keyfile"
  printf '\n[__config__]\nkeyfile = "%s"\n' "$keyfile" >> "$cfg"
fi

log "running nvchecker"
# --logger json emits one JSON object per result on stdout (stable interface):
#   {"name":"...","version":"2026.4.1390","event":"updated",...}
json_out="$(nvchecker -c "$cfg" --logger json 2>/dev/null || true)"
printf '%s\n' "$json_out" >&2

latest="$(printf '%s\n' "$json_out" | jq -rs --arg n "$name" '
  (map(select(.name == $n and (.version != null))) | last | .version) //
  (map(select(.version != null)) | last | .version) //
  empty' 2>/dev/null || true)"

[ -n "$latest" ] && [ "$latest" != "null" ] || die "$name: could not determine latest upstream version from nvchecker (see log above)"

has_update=false; regressed=false
if vercmp_gt "$latest" "$current"; then
  has_update=true
elif vercmp_gt "$current" "$latest"; then
  regressed=true
fi

log "$name: current=$current latest=$latest has_update=$has_update regressed=$regressed"
emit name "$name"
emit current "$current"
emit latest "$latest"
emit has_update "$has_update"
emit regressed "$regressed"
