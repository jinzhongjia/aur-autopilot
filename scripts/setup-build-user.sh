#!/usr/bin/env bash
# Create a non-root `builder` user with passwordless sudo. makepkg refuses to
# run as root, so every build/lint step runs as this user. Idempotent.
# Run as root inside the Arch container.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

[ "$(id -u)" -eq 0 ] || die "must run as root"

if ! id builder >/dev/null 2>&1; then
  useradd -m -s /bin/bash builder
  log "created user 'builder'"
fi

printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/builder
chmod 0440 /etc/sudoers.d/builder

# Avoid git "dubious ownership" for both root and builder on CI-owned checkouts
# and on the cloned work trees.
git config --global --add safe.directory '*' || true
runuser -u builder -- git config --global --add safe.directory '*' || true

log "build user ready"
