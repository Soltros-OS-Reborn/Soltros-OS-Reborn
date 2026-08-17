# Dotfile and Installer Repository Research

**Research date:** 2026-08-17
**Status:** Complete investigation. No configuration, package, installer, or
runtime behavior was changed from this research.

## Purpose

This document is the dedicated follow-up to
`desktop-polish-research-2026-08-17.md`. It records the complete investigation
of the dotfile repositories, one-click installers, configuration managers, and
desktop-shell projects found during the desktop-polish discovery pass.

The goal is not to adopt another distribution's configuration wholesale. The
goal is to identify deployable engineering patterns that improve SoltrOS Reborn
without violating its immutable Fedora 44 architecture, four-variant ownership
model, user-data safety, or license obligations.

## Scope and Evidence Standard

### Included

- Public dotfile, desktop-shell, rice, and one-click installation repositories
  discovered during the research pass.
- Local reference repositories in the parent project collection.
- Actual installation, update, backup, migration, removal, theme, and state
  management mechanisms inspected in upstream trees or README documentation.
- License metadata, maintenance signals, operational risks, and applicability
  to SoltrOS.

### Excluded

- General theme, icon, wallpaper, and operating-system comparisons already
  catalogued in `desktop-polish-research-2026-08-17.md`.
- An implementation decision, package addition, or configuration import.
- Unverified claims from repository screenshots, stars, or short descriptions.

### Evaluation Rules

1. A useful pattern must preserve immutable-image boundaries. The base image is
   built declaratively; a post-install script must not become a second package
   manager or alter the booted deployment unpredictably.
2. User configuration must never be overwritten without an explicit ownership
   record, preview, backup, and reversible result.
3. KDE, GNOME, Niri + Dank Material Shell (DMS), and Niri + Noctalia have
   independent session, portal, display-manager, and visual-default ownership.
4. DMS remains the sole dynamic-palette owner in the DMS variant. Noctalia
   remains the sole dynamic-palette owner in the Noctalia variant.
5. Reusing an idea is different from copying source or assets. Direct source,
   configuration, icon, font, and theme payload reuse requires verified
   provenance, license compliance, attribution, and a source-update policy.
6. A `NOASSERTION` GitHub license field or absent top-level license means that
   the source is not available for direct reuse until licensing is verified.

## SoltrOS Architectural Boundaries

| Area | Current SoltrOS rule | Consequence for imported patterns |
| --- | --- | --- |
| Image delivery | Fedora 44 bootc images are built from declared layers and overlays. | Do not use host-side `dnf`, AUR, COPR, curl-pipe, or source-build bootstrap as an image default. |
| Variants | KDE, GNOME, Niri + DMS, and Niri + Noctalia are isolated variants. | Package and config decisions must be variant-scoped when they affect a desktop shell, portal, or session. |
| LiveISO | A manifest-backed LiveISO selects and installs a chosen variant. | Installer choices must map to the existing manifest, remain offline-capable, and keep optional network updates opt-in. |
| User defaults | `/etc/skel` and first-login migration establish initial files. | Defaults need an ownership/version record and must preserve user modifications. |
| Dynamic color | DMS and Noctalia independently generate visual state. | Never introduce a shared wallpaper daemon or global GTK/Qt writer that races the existing shell. |
| OOBE and help | The product already has an initialization and help surface. | Shortcut discovery and optional personalization belong there, not in an additional shell or installer. |

## Executive Findings

The research repeatedly found seven patterns that are suitable for a future,
small SoltrOS enhancement after separate approval:

1. **Owned-default manifests:** record every file a SoltrOS migration creates
   or changes, preserve user edits, and create a `.soltros-new` candidate when
   an updated default would otherwise overwrite a modified file.
2. **Versioned migration ledger:** use idempotent, one-time migrations with
   completed-version state instead of an installer that reruns destructive
   setup each release.
3. **Explicit user override boundary:** use an included, user-owned custom file
   or a reserved `__custom__` namespace. Image updates preserve it untouched.
4. **Small, inspectable installers:** a future user-space tool should have
   preflight, dry-run, exact change preview, manifest-backed uninstall, and
   recorded rollback. It must not modify package repositories, drivers, or
   unrelated system configuration.
5. **Theme producer/consumer registry:** list static defaults and shell-owned
   generated artifacts so only one component writes each target.
6. **Hardware-local templates:** monitors, GPUs, location data, battery
   devices, and personal application choices need optional local includes, not
   baked image defaults.
7. **Surface coverage checklist:** polish work should account for launcher,
   terminal, lock/login, notifications, media, power, portals, accessibility,
   and application toolkit consistency without replacing the selected shell.

The common anti-patterns are equally clear: `git reset --hard`, broad
`rsync --delete`, direct copies over `~/.config`, automatic COPR/AUR/driver
installation, forced SDDM/GRUB changes, `chown -R "$HOME"`, user-specific
absolute paths, and always-on network synchronization. None is suitable for
SoltrOS.

## Complete External Repository Investigations

### end-4/dots-hyprland

- **Source:** <https://github.com/end-4/dots-hyprland>
- **Upstream metadata:** GPL-3.0; active at the time of research, with a push
  on 2026-08-15 and approximately 15.6k GitHub stars.
- **Inspected implementation:** `sdata/subcmd-install/1.deps-router.sh`,
  `sdata/subcmd-install/3.files.sh`, `sdata/subcmd-uninstall/0.run.sh`, and
  `sdata/dist-fedora/install-deps.sh`.

#### Observed architecture

The project routes installation by distribution and detects stale non-Arch
adapters by comparing timestamps. Its Fedora path reads a package TOML list,
tracks DNF transaction identifiers, manages COPR repositories, and uses a
local RPM repository. The configuration deployment step can prompt for backup,
write an installed-file list, synchronize files with `rsync`, retain changed
existing files as `.new` candidates, and save an applied-file manifest for
uninstallation. The uninstaller exposes the tracked list for review before
deleting paths.

#### Borrowable patterns

- Per-file default ownership manifests are the strongest finding in this
  project. SoltrOS can use the concept to distinguish an unmodified default
  from a user-managed file during first-login migration.
- An editable uninstall/rollback manifest is preferable to guessing which
  configuration files belong to an image or an optional user tool.
- Stale-adapter detection is useful as a CI warning: variant-specific overlay
  metadata can report when a supported Fedora interface has changed.
- Backup and restore state should be explicit artifacts, not an undocumented
  side effect of a copy command.

#### Not suitable for SoltrOS

- `rsync --delete` and tracked-path deletion can remove user data after a
  mistaken ownership record.
- COPR bootstrapping, local RPM trust changes, and `--nogpgcheck` are not
  appropriate in an immutable product image.
- DNF transaction handling is a mutable-host installer concern, not a bootc
  image-build primitive.
- Its Hyprland/Quickshell configuration cannot be substituted for either
  selected Niri shell.

#### Future applicability

Use its manifest and `.new` file principles only in the existing SoltrOS user
default migration. Any GPL-derived source copy would require a separate
license-compliance decision; no upstream configuration should be copied.

### caelestia-dots/shell

- **Source:** <https://github.com/caelestia-dots/shell>
- **Upstream metadata:** GPL-3.0; active at the time of research, with a push
  on 2026-08-16 and approximately 11.3k GitHub stars.
- **Evidence inspected:** upstream README and installation documentation.

#### Observed architecture

Caelestia is a full Quickshell desktop shell rather than a conventional
dotfile bundle. It offers AUR packaging, Nix execution/Home Manager modules,
and a manual CMake route. Wallpaper location, wallpaper commands, color scheme
selection, per-monitor configuration, and launcher fuzzy matching are
first-class documented settings. The project does not provide a conventional
shell installer/uninstaller in the inspected tree.

#### Borrowable patterns

- Treat wallpaper storage as a configurable user path rather than a hardcoded
  personal directory.
- Define per-monitor configuration as an explicit schema with safe defaults.
- Document shell CLI and IPC contracts, including who owns dynamic color state.
- The Nix/Home Manager module is a useful conceptual model for declarative,
  user-scoped configuration ownership.

#### Not suitable for SoltrOS

Caelestia is another full Niri-capable shell. Adding it would duplicate DMS
and Noctalia roles, create competing IPC and palette writers, and expand the
variant support matrix without a product need.

### prasanthrangan/hyprdots (HyDE)

- **Source:** <https://github.com/prasanthrangan/hyprdots>
- **Upstream metadata:** GPL-3.0; active repository at the time of research,
  last observed push 2025-03-23; approximately 8.5k GitHub stars.
- **Inspected implementation:** `Scripts/install.sh`, `Scripts/install_pkg.sh`,
  `Scripts/uninstall.sh`, `Scripts/themepatcher.sh`, and `README.md`.

#### Observed architecture

HyDE is an Arch-only, opinionated full desktop installer. It declares conflicts
with existing GTK/Qt theming, shell, SDDM, and GRUB configuration. It can
detect NVIDIA hardware and install `nvidia-dkms`, separates a theme repository
from its core configuration, offers a theme selector, and stores replaced
configuration in `~/.config/cfg_backups` for restoration. Its scripts cover
brightness, media, screenshots, GPU tools, launchers, system updates, and
portal-adjacent services.

#### Borrowable patterns

- Keep optional theme payloads on an independent version and lifecycle from
  the core desktop defaults.
- Maintain a desktop-surface compatibility matrix before selecting a theme.
- Present an explicit backup-before-restore warning for user-facing config
  operations.
- Use its broad surface list as a review checklist, not as a set of packages.

#### Not suitable for SoltrOS

Driver management, SDDM/GRUB overwrites, Arch-only package setup, forced
theme-conflict resolution, and global configuration replacement contradict the
image's immutable and multi-variant boundaries.

### mylinuxforwork/dotfiles (ML4W)

- **Source:** <https://github.com/mylinuxforwork/dotfiles>
- **Upstream metadata:** GPL-3.0; active at the time of research, with a push
  on 2026-08-16. Fedora, Arch, and openSUSE paths are supported.
- **Inspected implementation:** `README.md`, `setup/preflight-fedora.sh`,
  `setup/dependencies/packages-fedora`, `setup/migration.sh`, and the
  `dotfiles/.config/ml4w` listener, settings, and theme paths.

#### Observed architecture

ML4W supplies both a LiveISO path and an installer flow. The Fedora preflight
enables several COPRs for Hyprland, cursor assets, nwg-shell, Nerd Fonts, and
SwayNC. Settings are separated by concern, including browser, editor, power,
theme, blur, Waybar modules, quicklinks, monitoring, networking, and
Bluetooth. Dynamic Matugen behavior is handled by listener and post-hook
scripts with a colors JSON. The project consciously removes `swww` when
migrating toward `awww`.

#### Borrowable patterns

- Separate feature preferences from theme/layout data.
- Keep migration order distinct from dependency installation.
- Model optional desktop functions in small per-feature modules.
- Record a wallpaper backend migration as an integration change with rollback,
  rather than treating it as an isolated visual tweak.

#### Not suitable for SoltrOS

Its COPR stack, Hyprland assumptions, Waybar/SwayNC stack, and external
wallpaper backends cannot replace DMS or Noctalia. The Matugen hook model must
not write cross-variant global state.

### elpritchos/omadora

- **Source:** <https://github.com/elpritchos/omadora>
- **Upstream metadata:** MIT; active at the time of research. It targets Fedora
  44 Hyprland installation based on Omarchy.
- **Inspected implementation:** `install.sh`, `install/preflight/guard.sh`,
  `lib/state.sh`, `install/config/theme.sh`, `install/post-install/clean-up.sh`,
  and `migrations/`.

#### Observed architecture

Omadora has a strict phase sequence: `preflight -> packaging -> config ->
login -> post-install`. Its guard verifies Fedora release, non-root user,
x86_64 or aarch64 architecture, and a core-only Fedora expectation. State
flags are constrained files under `XDG_STATE_HOME`, and migrations are
timestamped. It maintains a current-theme path and connects Neovim, btop, and
Mako to its theme artifacts through symlinks. Installer output is logged.

#### Borrowable patterns

- Use exact OS, architecture, variant, and privilege preflight checks.
- Encode phase ordering rather than relying on a monolithic script order.
- Use safe, validated state names for toggles and completed migrations.
- Use user-scoped symlinked consumers only when the producer and target
  ownership are explicit.
- Preserve an installer log and a defined state directory for diagnosis.

#### Not suitable for SoltrOS

Direct `/etc` changes, package/group removal, global root cleanup, and
hard-coded browser policy changes are inappropriate. Theme consumers must not
be added to a DMS/Noctalia variant until the owner has declared the artifact.

### SNIPPIK/hyprdots

- **Source:** <https://github.com/SNIPPIK/hyprdots>
- **Upstream metadata:** MIT; active at the time of research. It is a small
  Arch-focused Niri + Noctalia configuration repository.
- **Inspected implementation:** `dotfiles/install.sh`,
  `dotfiles/.installer/packages.sh`, `dotfiles/.installer/themes.sh`,
  `dotfiles/sync.sh`, and Noctalia plugins under
  `dotfiles/Files/Configs/noctalia/plugins/`.

#### Observed architecture

The installer provisions packages, GPU drivers, desktop environment,
themes, SDDM, services, an AUR helper, and Noctalia. It bundles Noctalia
plugins for Arch updates, display settings, a keybind cheat sheet, and a
polkit agent, with language resources for plugin UI.

#### Borrowable patterns

- Evaluate Noctalia plugins as independent, optional modules rather than an
  indivisible configuration dump.
- A keybind cheat sheet is a useful discoverability pattern for the existing
  SoltrOS OOBE/help surface.
- Optional controls should have a clear module boundary and translated UI.

#### Not suitable for SoltrOS

Arch/AUR tooling, automatic driver and SDDM installation, hardcoded clone
paths, direct copies/deletions, and archive extraction must not be adopted.
Noctalia plugin selection also requires Fedora packaging and upstream API
compatibility verification before it can enter an image.

### adarsh-67r/niri-dots

- **Source:** <https://github.com/adarsh-67r/niri-dots>
- **Upstream metadata:** MIT; a personal Niri + DMS configuration, last
  observed push 2025-12-17.
- **Evidence inspected:** repository configuration and documented DMS settings.

#### Observed architecture

The settings catalogue includes theme mode, Material scheme, transparency,
animation, bar widgets, monitor/workspace behavior, terminal, GTK/Qt theming,
and OSD choices. It also embeds personal data and machine assumptions such as
weather coordinates, brightness device names, and font preference.

#### Borrowable patterns

The catalogue shows that DMS defaults should be curated as small,
variant-specific preferences. It is a useful input for a formal list of
supported SoltrOS DMS choices.

#### Not suitable for SoltrOS

Do not copy its complete settings file or any personal hardware, location,
network, font, or application assumptions. Before a DMS setting is seeded,
the exact schema must be inspected in the current image rather than inferred
from this personal configuration.

### AquilaIgnis/rice-cook

- **Source:** <https://github.com/AquilaIgnis/rice-cook>
- **Upstream metadata:** GPL-3.0; Fedora Hyprland rice installer, last observed
  push 2026-05-23.
- **Inspected implementation:** `README.md` and `preinstall.sh`.

#### Observed architecture

The script enables mirrors, RPM Fusion, Flathub, theme packages, fonts,
Catppuccin, Candy icons, and a Hyprland stack. It runs as root and recommends
`sudo chown -R "$USER:$USER" $HOME` after setup.

#### Borrowable patterns

Only its workload grouping can be useful: package candidates should be grouped
by system capability, desktop capability, optional tooling, and font coverage.

#### Not suitable for SoltrOS

Root-owned dotfile installation, recursive home ownership changes, mutable
post-install provisioning, and bulk global theme/font import are disallowed.

### liixini/skwd and liixini/skwd-wall

- **Sources:** <https://github.com/liixini/skwd> and
  <https://github.com/liixini/skwd-wall>
- **Upstream metadata:** MIT; both active at the time of research.

#### Observed architecture

`skwd` is a flexible Quickshell widget/shell collection for switchers,
launchers, media, notifications, bars, and power menus across Niri, Hyprland,
and KDE. `skwd-wall` manages image, video, and Wallpaper Engine selections,
Matugen color extraction, optional post-processing hooks, boot-time reapply,
multi-monitor targeting, image compression/downscale with retention, and
optional online or local-AI integrations. Its Fedora path recommends a COPR
and additional packages.

#### Borrowable patterns

- Define a bounded wallpaper retention policy before adding cache-producing
  visual tools.
- Model post-processing hooks as explicit, disabled-by-default placeholders.
- Describe multi-monitor wallpaper targeting as data rather than shell code.
- Test wallpaper persistence and reapplication as an end-to-end lifecycle.

#### Not suitable for SoltrOS

Neither project should become a third shell or a default wallpaper manager.
Video/Wallpaper Engine defaults, Steam/API/Ollama dependencies, external COPR
installation, and a second Matugen writer conflict with the current design.

### caioax/lyne-dots

- **Source:** <https://github.com/caioax/lyne-dots>
- **Upstream metadata:** GPL-3.0; active Arch + Hyprland/Quickshell repository.
- **Inspected implementation:** `install.sh`, `.install/README.md`,
  `.data/lyne-cli/commands/migrate.sh`, and
  `.data/lyne-cli/commands/update.sh`.

#### Observed architecture

The interactive installer offers categories for core tools, terminal, editor,
applications, utilities, fonts, Quickshell, theming, and optional NVIDIA. It
can perform Stow-only/setup-only operations or target a category. Local monitor,
environment, autostart, and keybind files use templates; GNU Stow controls
configuration links. The migration command records a `migrations-done` list.
Its update command invokes `git reset --hard`, then pulls, syncs, migrates,
and reloads.

#### Borrowable patterns

- Use a category selection model for optional user-space personalization.
- Isolate hardware-specific data in templates or optional include files.
- Provide a deploy-only and dry-run mode.
- Keep an idempotent completed-migration ledger.

#### Not suitable for SoltrOS

`git reset --hard`, automatic AUR installation, global GTK/Qt/Kvantum changes,
and Hyprland assumptions are unsuitable. Stow itself is not needed for image
defaults because a per-file ownership manifest gives SoltrOS stronger safety.

### Gakuseei/Ricelin

- **Source:** <https://github.com/Gakuseei/Ricelin>
- **Upstream metadata:** MIT; active at the time of research.
- **Inspected implementation:** `README.md` and `install.sh`.

#### Observed architecture

Ricelin provides a hand-written Quickshell/Hyprland shell with a thin
bootstrap. The bootstrap detects Arch, Debian, Fedora, and SUSE, ensures
`git` and `python3`, clones into the XDG data home, and transfers control to a
guided Python installer. The installer advertises `--quickstart`, `--full`,
`--sddm`, `--no-deps`, and `--dry-run`, together with configuration backups and
hardware-neutral monitor/GPU defaults. The project explicitly warns that the
installer is immature and should be read before use.

#### Borrowable patterns

- Keep a bootstrap small and make the substantive operation inspectable.
- Use package-manager family routing only for optional user-space utilities.
- Offer `--dry-run` and distinct clean-machine profiles.
- Start templates hardware-neutral and require a local override for specifics.

#### Not suitable for SoltrOS

Curl-pipe delivery, an extra Quickshell layer, SDDM changes, and Hyprland
configuration are not applicable.

### Nytril-ark/rumda

- **Source:** <https://github.com/Nytril-ark/rumda>
- **Upstream metadata:** active at the time of research; GitHub reports
  `NOASSERTION`, so direct reuse is blocked pending a manual license review.

#### Observed architecture

Rumda is a Hyprland/Quickshell rice with Yazi, Ghostty, Neovim, btop, Mako,
and screen tools. It uses theme selection variables and component booleans,
backs up existing `~/.config` files, and offers a user-requested destructive
`git reset --hard` update path.

#### Borrowable patterns

Its visible feature matrix and preflight checklist are useful models for an
approval UI: users should see exactly which optional component is selected.

#### Not suitable for SoltrOS

Raw configuration copying, destructive updates, ownership assumptions, and
unverified license status rule out any direct configuration or asset reuse.

### enhaoswen/Tide-island

- **Source:** <https://github.com/enhaoswen/Tide-island>
- **Upstream metadata:** GPL-3.0; active Niri/Hyprland Dynamic Island project.
- **Inspected implementation:** `README.md` and `install.sh`.

#### Observed architecture

The shell includes media, control center, timers, launcher, wallpaper picker,
overview, notification center, and feedback. It detects a compositor through
`TIDE_ISLAND_COMPOSITOR`, `XDG_CURRENT_DESKTOP`, then `$NIRI_SOCKET`. The
installer supports source tarballs with SHA256 verification, `--dry-run`,
`--uninstall`, `--skip-deps`, `--skip-quickshell`, `--no-service`, and
`--force`; it routes dependencies by distribution and pins a Quickshell commit.
Its documentation explicitly states that immutable systems should prefer
native packages or a mutable development container.

#### Borrowable patterns

- Use a documented detection priority with an explicit override.
- Require release checksums for any future optional downloaded artifact.
- Design dry-run, uninstall, and dependency-skip semantics before shipping a
  user-facing installer.
- State immutable-system compatibility plainly in tool documentation.

#### Not suitable for SoltrOS

The UI overlaps both selected Niri shells, and source installation under `/usr`
cannot be a bootc default. It is an installer quality reference only.

### myamusashi/vast-shell and Rexcrazy804/Zaphkiel

| Repository | Source | Metadata and observed finding | Decision |
| --- | --- | --- | --- |
| vast-shell | <https://github.com/myamusashi/vast-shell> | GPL-3.0 active Quickshell shell; inspected tree exposes README and license without a conventional installer. | Architecture reference only. No third shell. |
| Zaphkiel | <https://github.com/Rexcrazy804/Zaphkiel> | MIT active NixOS configuration; no conventional installer found. | Declarative configuration reference only; NixOS-specific payload is not applicable. |

## Local Reference Repository Investigations

### NyxNiri

- **Local path:** `/home/wangxianming/dev/OS/tools_and_themes/NyxNiri`
- **Remote:** `git@github.com:ech678/NyxNiri.git`
- **License:** GPL-3.0.
- **Inspected implementation:** `README.md`, `install.sh`, and
  `v2/noctalia/theme-sync.sh`.

#### Observed architecture

NyxNiri is an Arch/CachyOS Niri + Noctalia Material You configuration. It
offers a cache-directory curl bootstrap and a clone/repository workflow. Its
`nyxniri` command surface includes install, update, snapshot, rollback, list,
uninstall, purge, and doctor. Atomic updates preserve files and directories
matching `*__custom__*`; optional config backups live under
`~/.config/NyxNiri/backups`. `theme-sync.sh` writes GSettings plus GTK3/GTK4
settings according to Noctalia light/dark state.

#### Borrowable patterns

- A reserved custom namespace is a practical way to preserve explicit user
  customizations across controlled updates.
- SoltrOS default migration can use `.soltros-new` candidates when an updated
  owned default meets a modified target.
- A variant-specific shortcut view belongs in the existing OOBE/help surface.
- Dark/light propagation is a valuable concept when a selected shell has an
  exclusive, documented generated-output contract.

#### Not suitable for SoltrOS

Do not adopt curl-pipe bootstrap, mirror fallback automation, direct GSettings
and GTK overrides from Noctalia, or mpvpaper/video wallpaper. Noctalia must
remain the only dynamic color owner in its variant.

### LanRhyme-dotfiles

- **Local path:** `/home/wangxianming/dev/OS/tools_and_themes/LanRhyme-dotfiles`
- **Remote:** <https://github.com/LanRhyme/dotfiles>
- **License:** no verified top-level license was found during investigation;
  direct source reuse is not permitted.

#### Observed architecture

This is a Chezmoi-managed personal CachyOS configuration. A Noctalia wallpaper
hook invokes a Morandi color generator and rewrites Niri, Fcitx5, Starship,
Fastfetch, Alacritty, KDE/Qt colors, Blender, Limine, and proxy-aware
applications. It also schedules a two-hour automatic GitHub synchronization
and declares secret exclusions through `.chezmoiignore`.

#### Borrowable patterns

- Use explicit provenance and secret-exclusion lists for any generated or
  user-local state.
- Maintain an application-output registry that states which component writes
  which theme artifact.
- Document dynamic-color ownership as a product contract.

#### Not suitable for SoltrOS

Cross-application rewrites, automatic remote pushes, bootloader/Blender
changes, proxy configuration, and personal configuration cannot be imported.

### hyprvibe

- **Local path:** `/home/wangxianming/dev/OS/tools_and_themes/hyprvibe`
- **Remote:** `git@github.com:ChrisLAS/hyprvibe.git`
- **License:** AGPL-3.0.
- **Inspected implementation:** `switch-oh-my-posh-theme.sh` and
  `scripts/setup-monitors.sh`.

#### Observed architecture

The theme switcher creates a timestamped backup before copying the selected
prompt configuration. The monitor helper is Hyprland-specific and contains a
hardcoded `/home/chrisf/.config/hypr` path.

#### Borrowable patterns

Snapshot-before-switch is suitable as a user experience concept. A monitor
configuration should be represented as an intentionally local template or
include, never silently generated from another user's hardware.

#### Not suitable for SoltrOS

Do not copy AGPL shell code, user paths, or Hyprland-specific monitor tooling.

### Omarchy

- **Local path:** `/home/wangxianming/dev/OS/thirdparty_os/omarchy`
- **Remote:** `git@github.com:basecamp/omarchy.git`
- **License:** MIT.
- **Inspected implementation:** `install.sh`, `install/config/theme.sh`, and
  `install/first-run/gnome-theme.sh`.

#### Observed architecture

Omarchy uses the phase sequence `helpers -> preflight -> packaging -> config
-> login -> post-install`. Its theme system writes a current-theme pointer,
then btop and Mako consume theme assets through symlinks. The installer also
contains direct root changes and Chromium policy permission work.

#### Borrowable patterns

- A single current-theme pointer can reduce duplicated static theme choices.
- Explicit component configuration order reduces accidental racing writers.
- A user-scoped consumer link is safe only when both its source and target are
  clearly owned by the same selected theme provider.

#### Not suitable for SoltrOS

Do not adopt browser policy chmods, global root configuration, or direct
mutable host installation logic.

## Cross-Repository Pattern Matrix

| Pattern | Strong references | SoltrOS adoption direction | Required guard |
| --- | --- | --- | --- |
| File ownership manifest | dots-hyprland | Extend first-login migration metadata. | Never delete a file based only on a path match. |
| `.new` updated defaults | dots-hyprland, NyxNiri | Write `.soltros-new` for user-modified defaults. | Compare content/version before producing it. |
| Migration ledger | omadora, lyne-dots | One idempotent marker per migration version. | State must be user-scoped, schema-validated, and recoverable. |
| Reserved custom namespace | NyxNiri | Support an included user override or `__custom__` convention. | The shipped config must load it safely when absent. |
| Preflight and phases | omadora, Omarchy, Ricelin | Future user-space tooling gets strict variant/OS checks and ordered phases. | No root mutation or package-manager action. |
| Dry-run and exact preview | Ricelin, Tide-island, lyne-dots | Required before an optional config operation changes files. | Preview must use the same resolved manifest as apply. |
| Reversible uninstall | dots-hyprland, Tide-island | Remove only paths recorded by a successful apply operation. | Show manifest, backup, and exit status before deletion. |
| Theme consumer indirection | omadora, Omarchy | Document a current theme artifact where one producer owns it. | Do not cross DMS/Noctalia or global toolkit boundaries. |
| Hardware-local templates | lyne-dots, Ricelin, hyprvibe | Use optional monitor/hardware include files. | No personal paths, coordinates, device names, or guessed GPU policy. |
| Shortcut discovery | SNIPPIK, NyxNiri | Expand the existing OOBE/help surface. | Derive content from the chosen variant, not a generic third shell. |
| Wallpaper lifecycle tests | skwd-wall, ML4W | Test static wallpaper persistence and ownership. | Do not add a competing backend. |
| License/provenance registry | LanRhyme lessons, all source reviews | Record source, license, copied file, hash, and update policy. | No direct reuse for unverified/no-license repositories. |

## Recommended SoltrOS Work Packages After Approval

These are deliberately small, ordered work packages. They are not implemented
by this research report.

### 1. Strengthen User-Default Migration Safety

**Outcome:** each SoltrOS-managed initial configuration file has a known owner
and version. Existing user modifications survive updates; changed defaults
appear as reviewable `.soltros-new` files.

**Implementation shape:**

- Add a declarative manifest of default files, initial content hashes, and
  migration versions.
- Compare the last deployed SoltrOS hash with the current user file before
  replacing it.
- Preserve modified content and create a sibling candidate instead of an
  overwrite.
- Log per-file decisions and write a rollback manifest.
- Add contract tests for unmodified, user-modified, missing, and malformed
  state cases.

**Explicit non-goals:** no generic dotfile manager, no recursive home copy, no
`rsync --delete`, and no package installation.

### 2. Define a Variant-Scoped Override Contract

**Outcome:** users can customize a shipped Niri, terminal, or launcher default
in an obvious file that image updates never rewrite.

**Implementation shape:**

- Choose an existing native include mechanism for each applicable component.
- Ship only a documented example or empty optional include.
- Treat the include as user-owned and preserve it unconditionally.
- Keep DMS and Noctalia generated settings out of this generic override path.

**Validation:** boot each affected variant, verify missing and populated
overrides load cleanly, then update the image and confirm preservation.

### 3. Add a Product-Owned Migration Ledger

**Outcome:** one-time user-default migrations are transparent and idempotent.

**Implementation shape:**

- Store a versioned ledger under the relevant XDG state directory.
- Validate identifiers and content before reading state.
- Write completion only after all per-file actions and verification succeed.
- Support a diagnostic command that reports migration status without mutation.

**Validation:** run each migration twice in a disposable home and compare both
the resulting files and ledger content.

### 4. Evolve OOBE and Help Instead of Adding a Desktop Shell

**Outcome:** a user can discover variant shortcuts, defaults, and approved
optional personalization choices from an existing product UI.

**Implementation shape:**

- Source selected-variant facts from the manifest, not duplicated UI strings.
- Include a compact shortcut/help page only for commands that exist in that
  variant.
- Offer optional personalization only after it has an owned manifest, a
  dry-run preview, and rollback behavior.

**Explicit non-goal:** no full Quickshell, panel, dynamic island, or standalone
installer UI is added as a fifth environment.

### 5. Create a Theme Producer/Consumer Registry

**Outcome:** maintainers can see every static and generated visual artifact,
its owner, target variant, update event, and rollback source.

**Implementation shape:**

- Record static image defaults separately from runtime-generated outputs.
- Mark DMS and Noctalia paths as exclusive variant owners.
- Permit a consumer symlink only inside the owning variant and user scope.
- Gate package/theme additions on an entry in this registry.

**Validation:** check for conflicting writers in the image filesystem and
verify a wallpaper/color change only through its selected shell.

### 6. Establish an Optional Theme-Pack Intake Process

**Outcome:** future icon, terminal, or editor theme packs are reviewable and
reversible instead of copied from a personal repository.

**Required intake record:** source URL and revision, license text, copied file
inventory and hashes, attribution location, maintainer/update policy, package
or vendoring method, variant applicability, dependency ownership, test plan,
and rollback method.

## Explicit Anti-Patterns

The following findings are rejected for future SoltrOS installer or dotfile
work, even when they appear convenient in personal desktop projects:

- `curl | sh`, `curl | bash`, or any bootstrap that executes before source
  inspection and signature/hash verification.
- `git reset --hard` in an update command that may run in a user-controlled
  repository.
- Broad `rsync --delete`, `rm -rf`, archive extraction, or direct copy over
  `~/.config` without an owned-file manifest.
- Recursive ownership repair such as `chown -R "$USER:$USER" "$HOME"`.
- Automatic installation of GPU drivers, SDDM, GRUB, package groups, COPRs,
  RPM Fusion repositories, AUR helpers, or source-built system tools.
- A shared dynamic GTK/Qt theme writer that overlaps KDE, GNOME, DMS, or
  Noctalia ownership.
- Hardcoded user names, home directories, monitor outputs, brightness devices,
  weather locations, proxy settings, tokens, secrets, or personal paths.
- Automatic background Git synchronization or remote pushes from a desktop
  personalization component.
- Adding an overlapping shell, bar, launcher, wallpaper backend, notification
  center, or portal implementation without removing and validating the
  incumbent owner in one variant-specific design change.

## Delivery and Validation Gates for Any Future Adoption

Before a recommendation in this document becomes product behavior, require:

1. Confirm the current upstream license and source revision; record both in
   the repository provenance material.
2. Verify Fedora 44 availability in the target build container, including
   dependencies and the immutable-image update model.
3. Define the exact image/variant owner and prove it does not overlap an
   existing shell, palette generator, portal, display manager, or toolkit
   configuration owner.
4. Build a modified image and boot the real graphical variant in a disposable
   VM or equivalent graphical session.
5. Verify first login, existing-user migration, modified-user-config
   preservation, update behavior, and manifest-backed rollback.
6. Exercise the LiveISO path offline and with optional network updates disabled
   and enabled. Network updates must remain an explicit choice.
7. Run repository language, shell syntax, contract, `git diff --check`, and
   license/provenance checks before delivery.

## Conclusion

The investigated repositories offer valuable engineering patterns, especially
manifest-backed ownership, idempotent migrations, dry-run capability,
customization boundaries, current-theme consumer indirection, and clear
variant-specific discovery. Their typical one-click behavior is intentionally
not directly portable: most projects assume a mutable personal Arch or Fedora
workstation and allow replacement of user configuration, drivers, services, or
login components.

SoltrOS should borrow the disciplined parts of those systems while keeping the
image declarative, the four desktop variants isolated, the LiveISO offline
complete, and all user-file changes reviewable and reversible.

**No implementation was performed by this research document.**
