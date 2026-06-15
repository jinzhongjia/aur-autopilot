#!/usr/bin/env bash
# Dedupe guard: is there already an open "update-available" issue for this
# package + version? Requires GH_TOKEN in the environment.
# Usage: find-open-issue.sh <name> <version>
# Output: issue_exists (bool).
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

name="$1"; version="$2"; label="${3:-update-available}"
exists=false

n="$(gh issue list --state open --label "$label" \
      --search "$name $version in:title" --json number --jq 'length' 2>/dev/null || echo 0)"
if [ "${n:-0}" -gt 0 ] 2>/dev/null; then exists=true; fi

emit issue_exists "$exists"
log "$name $version: open update issue exists=$exists"
