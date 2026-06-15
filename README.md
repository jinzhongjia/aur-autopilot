# aur-autopilot

A GitHub **template repository** that keeps your [AUR](https://aur.archlinux.org/)
packages up to date with a human approval gate, driven by an AI agent.

Every day it checks each of your packages for a new **upstream** version. When one
appears it opens an issue with a fully validated proposal. You approve with a single
comment; CI runs the full packaging check and publishes the bump to the AUR.

- 🔎 **Detection** — `nvchecker`, daily, per package.
- 📝 **Proposal** — an issue with the diff, build result, and namcap output.
- 💬 **Interactive** — chat with the agent right on the issue ([pi](https://pi.dev) coding agent).
- ✅ **One approval → publish** — `/pi approve` → PR → packaging check → (auto-)merge → push to AUR.
- 🔒 **Safe by construction** — the agent has no shell and never holds your AUR SSH key.

> The agent runs as a GitHub Action via
> [`shaftoe/pi-coding-agent-action`](https://github.com/marketplace/actions/pi-github-action).
> Its model/provider/key are configured per repo via Secrets and Variables.

---

## How it works

This repo is a **controller**: it carries **no PKGBUILDs or build scripts**. Each
managed package is cloned fresh from the AUR at runtime (the AUR is the source of
truth and ships its own `.nvchecker.toml`). You list the packages you manage as tiny
`packages/<name>.toml` manifests.

```
                 ┌──────────────────── aur-autopilot ────────────────────┐
 daily cron ───► │ check-update    (matrix over packages/*.toml)          │
                 │   clone AUR (https) → nvchecker → vercmp               │
                 │   if newer & no open issue: build + namcap a candidate │
                 │   in an Arch container → open an issue                 │
                 └────────────────────────────────────────────────────────┘
                                   │  Issue: "Update available: <pkg> <ver>"
                                   ▼
   you ── "/pi approve" ─►  pi-agent   (only OWNER/MEMBER/COLLABORATOR)
                              opens a PR setting version in packages/<pkg>.toml
                                   │
                                   ▼
                           build-check   (PR gate, Arch container)
                             clone AUR → apply bump → makepkg + namcap + .SRCINFO
                                   │ green
                                   ▼  (AUTO_MERGE=true → auto-merge)
                           publish-aur   (on merge to default branch)
                             clone AUR → apply bump → push to AUR → close issue
```

**Why this split?** The pi agent is GitHub-API-only — it can read threads and open
PRs, but it has no shell and cannot run `makepkg`, compute checksums, or hold an SSH
key. So everything correctness- and security-sensitive (detection, checksums,
`.SRCINFO`, build, `namcap`, the AUR push) runs as **deterministic steps in an Arch
Linux container**. The agent is only the interactive + decision + PR-authoring layer.
The manifest edit *is* the approval artifact — small, reviewable, and git-tracked.

---

## Quick start

1. **Create your repo** from this template (green “Use this template” button), or
   `gh repo create my-aur --template <owner>/aur-autopilot`.

2. **Add a package.** Copy `packages.example.toml` to `packages/<aur-pkgbase>.toml`
   and set `name` + the current `version`:
   ```toml
   name    = "cloudflare-warp-bin"
   version = "2026.4.1390"
   ```
   The package must already exist on the AUR. Detection uses the `.nvchecker.toml`
   shipped in its AUR repo; if it has none, add an inline `[nvchecker]` table to the
   manifest (see `packages.example.toml`).

3. **Add Secrets and Variables** (Settings → Secrets and variables → Actions). See
   the [configuration table](#configuration) below.

4. **Create labels** — run the **bootstrap-labels** workflow once (Actions tab → Run
   workflow), or:
   ```bash
   gh label create update-available --color 0E8A16 -d "Upstream update proposed"
   gh label create build-failed     --color B60205 -d "Candidate packaging check failed"
   gh label create blocked-upstream  --color FBCA04 -d "Upstream anomaly, handle manually"
   ```

5. **Protect the default branch** (recommended): require the `build-check` status
   check. If you want one-comment-to-publish, also enable **Allow auto-merge**
   (Settings → General) and set the `AUTO_MERGE` variable to `true`.

6. **Try it**: Actions → **check-update** → Run workflow. If an update exists you’ll
   get an issue. Comment `/pi approve` to drive it to the AUR.

---

## Configuration

### Secrets

| Secret | Required | Purpose |
|---|---|---|
| `AUR_SSH_PRIVATE_KEY` | ✅ | Private SSH key registered on your AUR account. **Only** `publish-aur` reads it. |
| `PI_API_TOKEN` | ✅ | LLM API key (e.g. your DeepSeek key) — passed to the agent. |
| `GH_PAT` | ⭐ recommended | A token (classic `repo`, or fine-grained with **contents** + **pull requests** write) used by the agent to open PRs. Needed so agent-opened PRs trigger `build-check`/`auto-merge` — PRs created with the default `GITHUB_TOKEN` do **not** trigger other workflows. |

### Variables

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `AUR_USERNAME` | ✅ | — | Commit author name for AUR pushes. |
| `AUR_EMAIL` | ✅ | — | Commit author email for AUR pushes. |
| `PI_PROVIDER` | ✅ | — | LLM provider. For DeepSeek use `openai` (OpenAI-compatible). |
| `PI_MODEL` | ✅ | — | Model id, e.g. `deepseek-v4-flash`. |
| `PI_BASE_URL` | ➖ | provider default | For DeepSeek: `https://api.deepseek.com`. |
| `PI_THINKING_LEVEL` | ➖ | `off` | `off` \| `low` \| `medium` \| `high`. |
| `PI_TRIGGER` | ➖ | `/pi ` | Comment prefix that invokes the agent. |
| `AUTO_MERGE` | ➖ | `false` | `true` → auto-merge agent PRs once `build-check` is green. |

`GITHUB_TOKEN` is automatic and (by GitHub policy) cannot edit workflow files — the
agent is never asked to. `pkgname` is read from the manifest, never configured twice.

### Using DeepSeek (default LLM)

DeepSeek’s API is OpenAI-compatible. Set:

```
PI_PROVIDER  = openai
PI_BASE_URL  = https://api.deepseek.com
PI_MODEL     = deepseek-v4-flash      # or deepseek-v4-pro for harder reasoning
PI_API_TOKEN = <your DeepSeek API key>   (Secret)
```

See DeepSeek’s [Integrate with Pi](https://api-docs.deepseek.com/quick_start/agent_integrations/pi_mono)
guide. Any other provider pi supports (`anthropic`, `google`, `openai`, …) works too —
just set `PI_PROVIDER`/`PI_MODEL`/`PI_BASE_URL` accordingly.

### Package manifest (`packages/<name>.toml`)

```toml
name    = "cloudflare-warp-bin"   # AUR pkgbase (authoritative; file name is cosmetic)
version = "2026.4.1390"           # last approved/published version = publish target
# pkgrel = 1                      # optional, default 1 on a version bump
# [nvchecker]                     # optional: only if the AUR repo lacks .nvchecker.toml
# source = "regex"
# url    = "https://example.com/Packages"
# regex  = 'Version: (\d+\.\d+\.\d+)'
```

---

## The approval flow

1. **check-update** finds a newer upstream version, builds a validated candidate, and
   opens an **`update-available`** issue containing the diff, build log, and namcap
   output — plus instructions for the agent.
2. Discuss if you want: `/pi why did namcap warn about X?`, `/pi show the diff`, etc.
   The agent replies in the thread.
3. **Approve** with `/pi approve`. The agent opens a PR that sets `version` in the
   package manifest (it transcribes the validated target — it never edits checksums).
4. **build-check** runs on the PR: clone the package from the AUR, apply the bump,
   `makepkg` + `namcap` + `.SRCINFO` sync. This is the required gate.
5. **Merge** — automatically if `AUTO_MERGE=true` (needs `GH_PAT` + “Allow auto-merge”
   + branch protection), or click Merge yourself.
6. **publish-aur** pushes the bump to the AUR (using `AUR_SSH_PRIVATE_KEY`) and closes
   the issue.

Only one human action (the approve comment, plus the merge click if auto-merge is off)
is required. Safety comes from the candidate being validated *before* the issue and CI
re-validating *before* the push.

> **Without `GH_PAT`:** the agent still chats and opens PRs, but PRs it creates with
> the default token won’t auto-trigger `build-check`/`auto-merge`. Re-run `build-check`
> manually (Actions → build-check → Run workflow, pick the manifest) or push a trivial
> commit, then merge. On merge, `publish-aur` runs normally.

---

## Security model

- **Trigger gating** — `pi-agent` runs only when the commenter is `OWNER`/`MEMBER`/
  `COLLABORATOR`, the comment starts with the trigger phrase, and the sender is not a
  bot. Strangers cannot spend your API budget or open PRs.
- **The agent never holds the AUR key** — `AUR_SSH_PRIVATE_KEY` is referenced only in
  `publish-aur`. It is not in the agent job’s environment, and the agent has no shell.
- **Separation of duties** — the agent only edits a small TOML via the GitHub API; all
  building, checksum computation, and the AUR push are deterministic container steps.
- **Pinned actions** — every third-party action is pinned to a full commit SHA;
  `dependabot.yml` keeps them current.
- **Least privilege** — each workflow requests the minimum token scopes.
- **No `.pi/` config shipped** — the pi agent reads repo-local config if present; this
  repo ships none. Review any `.pi/` addition like code.

---

## Managing multiple packages

Add one `packages/<name>.toml` per package. `check-update` fans out over all of them
(a build matrix), and `build-check`/`publish-aur` act only on the manifests changed in
a given PR/merge. There is no limit beyond your runner minutes.

## Requirements for a managed package

- It exists on the AUR and you can push to it (`ssh aur@aur.archlinux.org` works with
  your key).
- It has a static `pkgver` (binary/`-bin` and release-tarball packages — not VCS
  packages that compute `pkgver()` dynamically).
- Upstream detection is available: either a `.nvchecker.toml` in its AUR repo, or an
  inline `[nvchecker]` table in the manifest.
- Packages using an `epoch` are detected but not auto-bumped — `check-update` flags a
  `blocked-upstream` issue instead, for you to handle by hand.

---

## Local testing

The scripts are designed to run in `archlinux:base-devel`. To dry-run the whole
pipeline against a package on your own machine (Docker/Podman):

```bash
podman run --rm -it -e WORKDIR=/tmp/work -e MAKEPKG_DEPS=0 \
  -v "$PWD":/repo:ro -w /repo archlinux:base-devel bash
# inside the container:
pacman -Syu --noconfirm --needed pacman-contrib namcap git jq python nvchecker sudo github-cli
./scripts/setup-build-user.sh
printf 'name = "cloudflare-warp-bin"\nversion = "2026.4.1390"\n' > /tmp/m.toml
dir=$(./scripts/clone-aur.sh /tmp/m.toml read)
./scripts/detect-update.sh /tmp/m.toml "$dir"          # detection
./scripts/verify-manifest.sh /tmp/m.toml               # the PR gate (build + namcap)
DRY_RUN=true AUR_USERNAME=me AUR_EMAIL=me@example.com \
  ./scripts/publish-manifest.sh /tmp/m.toml            # publish dry-run (no push)
```

`MAKEPKG_DEPS=0` skips installing runtime dependencies (handy for `-bin` packages that
only repackage a binary). CI uses the default (`1`) for a full check. Set
`AUR_READ_BASE` to clone from a mirror or a local `file://` path instead of the AUR.

You can also lint everything:

```bash
podman run --rm -v "$PWD":/mnt:ro -w /mnt koalaman/shellcheck:stable -x scripts/*.sh
podman run --rm -v "$PWD":/repo:ro -w /repo rhysd/actionlint
```

---

## Layout

```
packages/<name>.toml      # one per managed AUR package (you add these)
scripts/                  # deterministic automation (run in an Arch container)
.github/workflows/
  check-update.yml        # daily: detect → open issue
  pi-agent.yml            # interactive agent + approval PR
  build-check.yml         # PR gate: clone + bump + makepkg + namcap + .SRCINFO
  publish-aur.yml         # on merge: push the bump to the AUR
  auto-merge.yml          # optional: auto-merge agent PRs when AUTO_MERGE=true
  bootstrap-labels.yml    # one-shot: create the labels
```

## License

MIT — see [LICENSE](LICENSE). (Applies to this tooling; each AUR package keeps its own
license declared in its PKGBUILD.)
