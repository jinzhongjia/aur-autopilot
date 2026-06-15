#!/usr/bin/env bash
# Print changed packages/*.toml between two git refs, one per line. If the base
# ref is unknown (first push / force-push), print all manifests.
# Usage: changed-manifests.sh <base-ref> [head-ref]
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

base="${1:-}"; head="${2:-HEAD}"
cd "$(repo_root)"
shopt -s nullglob

if [ -z "$base" ] || ! git cat-file -e "${base}^{commit}" 2>/dev/null; then
  for f in packages/*.toml; do printf '%s\n' "$f"; done
  exit 0
fi

git diff --name-only "$base" "$head" -- 'packages/*.toml' || true
