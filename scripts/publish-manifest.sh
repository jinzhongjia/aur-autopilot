#!/usr/bin/env bash
# Apply the manifest `version` to the package's AUR repo and push it.
# Run as root in the Arch container. Requirements:
#   - the AUR SSH key already configured for `ssh aur@aur.archlinux.org`
#   - AUR_USERNAME / AUR_EMAIL in env (commit identity)
# Optional:
#   - DRY_RUN=true        build + show staged diff, do NOT push or close
#   - GH_TOKEN + GH_REPO  close the linked issue after a successful push
# Usage: publish-manifest.sh <manifest>
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

manifest="$(realpath -- "$1")"
name="$(manifest_get "$manifest" name)"
target="$(manifest_get "$manifest" version)"
: "${AUR_USERNAME:?AUR_USERNAME required}"
: "${AUR_EMAIL:?AUR_EMAIL required}"

# Clone read-only (https); we only switch to the SSH push URL at push time, so
# dry-runs and the bump never need the AUR key.
dir="$("$LIBDIR/clone-aur.sh" "$manifest" read)"
chown -R builder "$dir" 2>/dev/null || true

# Re-apply the bump deterministically (recomputes checksums, regenerates .SRCINFO)
# and re-validate .SRCINFO sync. The heavy build already ran in build-check on the
# merged content; we keep publish light.
runuser -u builder -- "$LIBDIR/apply-bump.sh" "$manifest" "$dir" "$target"
runuser -u builder -- "$LIBDIR/srcinfo-check.sh" "$dir"

cd "$dir"
git config user.name "$AUR_USERNAME"
git config user.email "$AUR_EMAIL"
git add -- PKGBUILD .SRCINFO

if git diff --cached --quiet; then
  log "$name: AUR already at $target — nothing to publish"
  exit 0
fi

if [ "${DRY_RUN:-false}" = "true" ]; then
  log "DRY_RUN: would commit 'v$target' and push to AUR. Staged diff:"
  git --no-pager diff --cached >&2
  exit 0
fi

git commit -m "v$target"
git remote set-url origin "ssh://aur@aur.archlinux.org/${name}.git"
git push origin HEAD:master
log "$name: published v$target to the AUR"

# Best-effort: comment on and close the linked issue.
if [ -n "${GH_TOKEN:-}" ]; then
  num="$(gh issue list --state open --label update-available \
          --search "$name $target in:title" --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [ -n "$num" ]; then
    gh issue comment "$num" --body "Published \`v$target\` to the AUR. 🎉"
    gh issue close "$num"
    log "closed issue #$num"
  fi
fi
