#!/usr/bin/env bash
# Render the Markdown body for an "update available" issue. Prints to stdout.
# Usage: render-issue.sh <name> <current> <latest> <diff-file> [pkg-log] [status]
#   status: ok (default) | failed  — whether the candidate packaging check passed
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname -- "$0")/lib.sh"

name="$1"; current="$2"; latest="$3"; difffile="$4"; buildlog="${5:-}"; status="${6:-ok}"
maxlog=120
trigger="${PI_TRIGGER:-/pi }"
trig="$(printf '%s' "$trigger" | sed 's/[[:space:]]*$//')"

printf '## Upstream update available — `%s`\n\n' "$name"
printf '|  | version |\n|---|---|\n| current (AUR) | `%s` |\n| latest (upstream) | `%s` |\n\n' "$current" "$latest"

if [ "$status" = "ok" ]; then
  printf 'A candidate build of `%s` was prepared and **passed the packaging check** (makepkg build + namcap + `.SRCINFO` sync) before this issue was opened.\n\n' "$latest"
else
  printf '> ⚠️ A candidate build of `%s` was prepared but the **packaging check FAILED**. Review the log below before approving.\n\n' "$latest"
fi

printf '### What to do\n'
printf -- '- Comment **`%s approve`** to open the update PR. CI re-runs the full build, and on success it is published to the AUR.\n' "$trig"
printf -- '- Comment **`%s <question>`** to discuss the change with the agent.\n' "$trig"
printf -- '- Close this issue to reject the update.\n\n'

printf '### Proposed change\n```diff\n'
cat -- "$difffile"
printf '\n```\n'

if [ -n "$buildlog" ] && [ -f "$buildlog" ]; then
  printf '\n<details><summary>Candidate packaging log (last %s lines)</summary>\n\n```\n' "$maxlog"
  tail -n "$maxlog" -- "$buildlog"
  printf '```\n</details>\n'
fi

manifest_path="${MANIFEST_PATH:-packages/${name}.toml}"
printf '\n<details><summary>Agent instructions (on approval)</summary>\n\n'
printf 'When a maintainer approves, open a pull request that:\n'
printf '1. Edits `%s`, setting `version = "%s"`.\n' "$manifest_path" "$latest"
printf '2. Has a body containing `Closes #<this issue number>`.\n'
printf '3. Is titled `%s %s`.\n\n' "$name" "$latest"
printf 'Do not modify anything under `.github/`, and do not edit PKGBUILD or checksums here — CI clones the package from the AUR, applies the bump, recomputes checksums, builds, and publishes.\n'
printf '</details>\n'

# Machine-readable marker: the agent reads this to learn the package, target
# version, and manifest path unambiguously when asked to open the update PR.
printf '\n<!-- aur-autopilot:{"pkg":"%s","version":"%s","manifest":"%s"} -->\n' "$name" "$latest" "$manifest_path"
