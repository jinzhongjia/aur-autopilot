#!/usr/bin/env bash
# Shared helpers for aur-autopilot scripts. Source this; do not execute.
#
# These scripts are the DETERMINISTIC core. They run in an Arch Linux container
# (or natively on an Arch host) and perform every correctness/security-sensitive
# operation: upstream detection, checksum computation, .SRCINFO regeneration,
# makepkg builds, namcap. The pi agent never runs any of this.

# Absolute dir of this library (so we can find sibling files like manifest.py
# even after a caller has cd'd elsewhere).
LIBDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIBDIR

log() { printf '[%s] %s\n' "$(basename -- "${0:-lib}")" "$*" >&2; }

die() {
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then printf '::error::%s\n' "$*" >&2; fi
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# emit KEY VALUE — write a step output when running under Actions, else print it.
emit() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"
  else
    printf '%s=%s\n' "$1" "$2"
  fi
}

repo_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

# --- Manifest (packages/<pkg>.toml) accessors, backed by Python's tomllib ----
manifest_get()    { python3 "$LIBDIR/manifest.py" get "$1" "$2"; }
manifest_get_or() { python3 "$LIBDIR/manifest.py" get-or "$1" "$2" "$3"; }
manifest_has_nvchecker() { [ "$(python3 "$LIBDIR/manifest.py" has-nvchecker "$1")" = "true" ]; }
# Emit a self-contained nvchecker config (a single [<name>] section) to stdout.
manifest_nvchecker_toml() { python3 "$LIBDIR/manifest.py" nvchecker-toml "$1"; }

# Read the static pkgver from a cloned PKGBUILD by sourcing it in a subshell.
# (Epoch is intentionally ignored: it is a packaging decision orthogonal to the
# upstream version we compare against. Packages using an epoch are handled by
# the maintainer by hand.)
pkgbuild_pkgver() {
  ( cd "$1" && set +eu +o pipefail; source ./PKGBUILD >/dev/null 2>&1; printf '%s\n' "${pkgver:-}" )
}

# vercmp_gt A B — true (exit 0) iff A is strictly newer than B, per pacman's vercmp.
vercmp_gt() {
  local r
  r="$(vercmp "$1" "$2")"
  [ "$r" -gt 0 ]
}
