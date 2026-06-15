<!-- aur-autopilot version-bump PR -->
## Summary

<!-- Package and old → new version. The agent fills this in on `/pi approve`. -->

## Checklist

- [ ] Closes the corresponding `update-available` issue (`Closes #<n>`)
- [ ] Only `packages/*.toml` changed (no PKGBUILD / build scripts live in this repo)
- [ ] `build-check` is green — it clones the package from the AUR, applies the bump,
      then runs `makepkg` + `namcap` + `.SRCINFO` sync

After merge, `publish-aur` clones the package, re-applies the bump, pushes it to the
AUR, and closes the issue.
