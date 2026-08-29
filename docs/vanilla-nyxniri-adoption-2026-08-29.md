# Vanilla OS and NyxNiri Adoption Record

Date: 2026-08-29

This record captures the repository and reference-project review that preceded
the current implementation. It is deliberately scoped to behavior that fits
SoltrOS Reborn's Fedora 44 bootc, four-image, and offline LiveISO architecture.

## Sources Reviewed

### Vanilla OS

- `ABRoot` (`eeb93d3`, 2026-08-25): OCI-backed immutable transactions, current/future
  state, rollback, rebase, operation locking, package diffs, and staged boot.
- `apx` (`36f2e86`, 2026-08-25): managed container subsystems, package-manager
  definitions, stack profiles, and distro-agnostic command routing.
- `vanilla-installer` (`af70c37`, 2026-08-28): GTK4/Libadwaita frontend separated
  from an installer backend and custom recipe input.
- `first-setup` (`05e64eb`, 2026-07-22): explicit setup modes, dry-run support,
  locale/keyboard/timezone/hostname/user pages, and task-oriented completion.
- `live-iso` (`2be3bc7`, 2026-08-28): channel-driven, containerized, privileged ISO
  builds with a separate build output.
- `vanilla-gnome-default-settings` (`abf3497`): packaged GSettings defaults,
  wallpaper registration, touchpad/power defaults, and Flatpak preference.
- `vanilla-control-center`, `vanilla-updater`, `vanilla-recovery-utility`, and
  `almost` were also inspected. Their local revisions are old or explicitly
  deprecated and are reference material only, not adoption targets.

### NyxNiri

- HEAD `4a83fe8` (2026-08-24), plus an uncommitted personal-preference worktree:
  Niri shortcut alignment, monitor/workspace operations, Noctalia session
  wrapper, GTK template cleanup, and additional Nyx tools.
- `design/tokens.toml`: centralized color, shape, spacing, typography, motion,
  accessibility, and launcher dimensions.
- `configs/noctalia/theme-sync.sh`: lock-protected, atomic GTK/GSettings/Portal/
  Kitty synchronization with legacy CSS cleanup.
- Modular Niri includes, Dunder custom-file preservation, optional wallpapers,
  Fcitx5 theme templates, and isolated editor/media configurations.

## Adopted in SoltrOS

| Area | Adopted behavior | SoltrOS location | Status |
| --- | --- | --- | --- |
| Theme source | One dark-blue token registry for static surfaces and generated/runtime consumers | `system_files/usr/share/soltros/theme/tokens.toml` | Implemented |
| Noctalia session | Establishes runtime DBus, Wayland, Pulse, and desktop variables before starting the shell | `system_files/usr/bin/soltros-noctalia-session` | Implemented |
| Theme synchronization | Uses a runtime lock and atomic writes; broadcasts GTK/GSettings state and reloads supported clients | `system_files/usr/libexec/soltros/noctalia-theme-sync` | Implemented |
| Niri customization | Adds an optional user override include without replacing the managed base configuration | `desktop_files/niri-common/etc/skel/.config/niri/config.kdl` | Implemented |
| Container workspaces | Declares supported Distrobox development profiles instead of embedding package-manager policy in UI code | `system_files/usr/share/soltros/workspaces.json` | Implemented |
| Lifecycle UX | Keeps bootc authoritative while documenting current/staged/rollback presentation requirements | `system_files/usr/libexec/soltros/system.sh`, `docs/architecture-roadmap.md` | Implemented/documented |

## Intentionally Not Adopted

- ABRoot's A/B root partition implementation: bootc/OSTree already provides the
  deployment transaction and rollback contract for SoltrOS.
- `almost` file-attribute locking: it can conflict with bootc, SELinux, package
  installation, and administrator recovery.
- Apx itself: SoltrOS already ships Distrobox, Toolbox, Nix, and Flatpak. We use
  the profile/subsystem idea without adding another package-manager frontend.
- Deprecated Vanilla Control Center and old updater/recovery implementations.
- NyxNiri's Arch/AUR commands, hard-coded home paths, fixed `WAYLAND_DISPLAY`,
  personal keymap choices, and optional video-wallpaper payloads as image defaults.

## Implementation Plan and Evidence

1. Record this review and keep license/provenance boundaries explicit. **Done.**
2. Install the token registry and validate that all static theme surfaces use the
   documented SoltrOS palette. **Done.**
3. Add a Noctalia session wrapper and an atomic, lock-protected theme sync entry
   point; keep Noctalia as the sole dynamic palette owner. **Done.**
4. Add a user-preserved Niri override include and declarative Distrobox workspace
   profiles. **Done.**
5. Extend focused contract tests and run shell/Python syntax, project tests,
   whitespace, and language scans. **Done, with the host `just` check unavailable.**

## Licensing Boundary

Vanilla OS components and NyxNiri are GPL-family projects. This change adopts
interfaces and behavior, not copied source. Any future code or asset import must
record the exact repository, commit, file, license, and modification in
`docs/third-party-attribution.md`. Vanilla wallpapers include CC-BY and
CC-BY-SA assets and must not be copied into the SoltrOS image without per-file
attribution and share-alike review.
