#!/usr/bin/env bash
# Enumerate managed package manifests (packages/*.toml) and emit a workflow
# matrix. Outputs: count, matrix={"manifest":[...]}.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

cd "$(repo_root)"
shopt -s nullglob
files=( packages/*.toml )

json="$(printf '%s\n' "${files[@]}" | jq -R 'select(length>0)' | jq -cs .)"
[ -z "$json" ] || [ "$json" = "null" ] && json="[]"

emit count "${#files[@]}"
emit matrix "{\"manifest\":$json}"
log "found ${#files[@]} package manifest(s)"
