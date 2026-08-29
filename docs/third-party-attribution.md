# Third-Party Runtime Assets

This file records the third-party payloads that are downloaded and installed
during the image build. The source lock is authoritative for the exact version,
commit, and archive digest.

## Yazi

- Upstream: <https://github.com/sxyazi/yazi>
- Version: `26.8.15`
- License: MIT, distributed with the release archive as `LICENSE`
- Payload: `yazi`, `ya`, and shell completions for Bash, Fish, and Zsh
- Install paths: `/usr/bin`, `/usr/share/licenses/yazi`, and the system
  completion directories
- Update mechanism: update `yazi.version` and both architecture-specific
  digests in `release/sources.lock.json`, then rerun the image build
- Rollback: bootc rollback or build from the previous source-lock revision

Yazi is an explicit terminal file manager. It does not replace Nautilus,
Dolphin, desktop portals, MIME associations, or file chooser defaults.

## MoreWaita

- Upstream: <https://github.com/somepaulo/MoreWaita>
- Locked commit: `5438528502c6ee6473ede1087ed46c3872535f5f`
- License: GPL-3.0-only, distributed as `LICENSE`
- Additional attribution: upstream `README.md` and `AUTHORS` are installed
  under `/usr/share/doc/MoreWaita`
- Payload: the upstream `MoreWaita` icon theme under `/usr/share/icons`
- Default behavior: optional; `Papirus-Dark` remains selected by shared GTK,
  KDE, GNOME, and DMS defaults
- Update mechanism: update the locked commit and source archive digest in
  `release/sources.lock.json`, review the upstream license and attribution,
  then rerun the image build
- Rollback: remove the MoreWaita install block and bootc rollback; the
  Papirus-Dark default does not depend on this payload

MoreWaita is selectable through the native icon-theme settings of KDE Plasma,
GNOME Tweaks, and Dank Material Shell. No generated DMS or Noctalia palette is
derived from this optional icon payload.

## Architecture References

The following projects informed design decisions in the 2026-08-29 adoption
record. No source code, theme file, wallpaper, or branding asset from these
repositories is included in the SoltrOS image.

- Vanilla OS `ABRoot` (`eeb93d3`): GPL-3.0. Referenced for current/future
  deployment status, operation locking, package diffs, and rollback UX. Its A/B
  partition implementation is not used because bootc is SoltrOS's deployment
  authority.
- Vanilla OS `apx` (`36f2e86`): GPL-3.0. Referenced for declarative container
  subsystem profiles; SoltrOS implements this boundary with Distrobox.
- Vanilla OS `first-setup` (`05e64eb`): GPL-3.0. Referenced for explicit setup
  modes and dry-run/task UX; SoltrOS retains its own cross-desktop OOBE.
- Vanilla OS `vanilla-backgrounds`: CC-BY and CC-BY-SA assets were reviewed but
  are not redistributed by SoltrOS.
- NyxNiri (`4a83fe8` and the reviewed personal-preference worktree): GPL-3.0.
  Referenced for design tokens, atomic theme synchronization, modular Niri
  includes, and user customization preservation. Arch/AUR commands and personal
  assets are not included.

## KDE Material You Colors

- Upstream: <https://github.com/luisbocanegra/kde-material-you-colors>
- Version: `2.2.0`
- License: GPL-3.0-only, distributed with the wheel as `LICENSE`
- Dependency: `materialyoucolor 3.0.4`, also GPL-3.0-only
- Scope: KDE image only; installed but disabled until the user runs
  `soltros-theme kde-material-you enable`
- Behavior: a user-level service derives a dark Material 3 palette from the
  bundled SoltrOS wallpaper; KDE and Konsole files are backed up before the
  first enable operation
- Rollback: `soltros-theme kde-material-you disable` stops the service and
  restores the `.soltros-backup` files

## Pywalfox Native Host

- Upstream: <https://github.com/Frewacom/pywalfox-native>
- Version: `2.9.0`
- License: MPL-2.0, distributed with the wheel as `LICENSE`
- Scope: Niri + Dank Material Shell image only
- Behavior: `soltros-theme waterfox enable` creates a per-user Waterfox
  native-messaging manifest; it does not install an extension or touch a
  browser profile. The user must install the Pywalfox extension separately.
- Rollback: `soltros-theme waterfox disable` removes the generated manifest and
  restores any pre-existing Flatpak override file

## Ghostty

- Upstream: <https://github.com/ghostty-org/ghostty>
- Version: `1.3.1`
- License: MIT, distributed with the source archive as `LICENSE`
- Build inputs: Zig `0.15.2`; both the Ghostty archive and its minisign file
  are digest-locked and the archive is verified with the upstream public key
- Scope: Niri + Dank Material Shell image only; Kitty remains the DMS default
- Behavior: `soltros-theme ghostty enable` changes only the user's DMS terminal
  override to Ghostty. DMS owns the generated `dankcolors` theme.
- Rollback: `soltros-theme ghostty disable` restores the backed-up DMS settings
  or explicitly selects Kitty
