# Desktop Polish Research and Approval-Gated Plan

**Research date:** 2026-08-17
**Status:** Research complete. No candidate in this document has been added to
the image or enabled for users.

## Purpose

This document records the complete external desktop-polish discovery pass after
the initial SoltrOS Reborn dark-blue implementation. It separates sources that
were found from changes that are suitable for this immutable Fedora 44 image
matrix. The intent is to make an approval decision before adding packages,
configuration, source payloads, or services.

The research covers operating systems, themes, icon sets, configuration and
dotfile repositories, desktop-shell integrations, wallpaper tools, terminal
applications, browser integration, and graphical monitoring tools.

## Current Baseline

The current image matrix contains four isolated variants:

| Variant | Existing visual ownership |
| --- | --- |
| KDE Plasma | Breeze Dark, Papirus Dark, Adwaita cursor, branded wallpaper, Konsole profile |
| GNOME | libadwaita dark preference, GNOME blue accent, Papirus Dark, branded wallpaper registration |
| Niri + Dank Material Shell | Niri colors and depth, DMS-owned dynamic Material palette, Kitty and Alacritty theme imports |
| Niri + Noctalia | Niri colors and depth, Noctalia-owned wallpaper palette and shell configuration |

Shared defaults already include dark GTK3/GTK4 settings, Papirus Dark, a 24px
Adwaita cursor, JetBrains Mono, Starship, Fastfetch, btop, Alacritty, Fuzzel,
and a generated SoltrOS Electric Blue wallpaper. The current gaming and system
layers already contain GameMode, MangoHud, GOverlay, nvtop, and a Mission
Center entry for the LiveISO.

The following boundaries remain mandatory:

- DMS owns generated Material colors in the DMS variant.
- Noctalia owns dynamic wallpaper colors in the Noctalia variant.
- KDE and GNOME must use their native settings surfaces.
- A package or service must not replace an existing shell, bar, launcher,
  notification center, portal, wallpaper owner, or display manager without a
  specific variant-level design decision.
- Dynamic DMS output is only validated in a disposable image session. Host
  automation uses a command test double and never invokes real DMS generation.

## Research Method and Evidence

### Sources Consulted

- Tavily web searches for Fedora 44 theming, immutable desktop operating
  systems, Plasma 6 customization, GNOME Shell extensions, Wayland wallpaper
  tooling, Quickshell/dotfile projects, icon themes, terminal tools, and DMS
  integrations.
- GitHub repository metadata for active status, default branch, archive state,
  description, and SPDX license information where declared.
- Fedora Packages pages for package availability where search results were
  conclusive.
- The official DMS application-theming documentation and current DMS releases.
- The current SoltrOS package lists, Flatpak references, overlays, contracts,
  and visual ownership documentation.

### Verification Limitation

The development host does not have `dnf5`, so local `repoquery` cannot prove
Fedora 44 availability for every candidate. Fedora Packages confirms
`adw-gtk3-theme` for Fedora 44. Other RPM availability must be checked inside
a Fedora 44 build container before an implementation is committed. A missing
local `dnf5` command is not evidence that a package is unavailable in Fedora.

### Source Reliability Rules

- A current, non-archived upstream with an explicit license is preferred.
- Fedora-packaged software is preferred over source builds in the immutable
  base image.
- A source build, COPR, Flatpak, extension store install, or browser add-on is
  never made a default without a separate update, rollback, and runtime QA
  plan.
- GitHub `NOASSERTION` means repository metadata did not declare an SPDX
  identifier. It is not treated as a usable license until the source tree is
  inspected.
- A visual reference may inform an original SoltrOS configuration even when no
  source or asset is copied.

## Full Discovery Inventory

### Immutable and Fedora Desktop References

| Source | Finding | Reusable lesson | Decision |
| --- | --- | --- | --- |
| [Bluefin](https://docs.projectbluefin.io/) | Immutable Fedora desktop images emphasize upstream proximity, controlled layers, and explicit user setup boundaries. | Keep visual defaults declarative and preserve user configuration through migration instead of overwrite. | Already reflected in the shared/variant overlay and migration design. No additional source reuse. |
| [Aurora](https://getaurora.dev/) | KDE-focused immutable desktop delivery demonstrates that a polished desktop can remain image-based. | Treat Plasma appearance as a variant concern rather than a shared mutable script. | Architecture-only reference; no new payload selected. |
| [Bazzite](https://bazzite.gg/) | Gaming-focused Fedora image design validates a curated base plus optional user-space tools. | Add visual tools only when they fit the immutable update model and do not duplicate existing gaming utilities. | Existing gaming layer already covers MangoHud, GOverlay, GameMode, and nvtop. |
| Universal Blue base-image guidance | Base images should remain close to Fedora while derived images carry opinionated changes. | Prefer small native overlays over a large cross-desktop theme framework. | Continue the existing image architecture. |
| Immutable wallpaper-engine reports | Plasma wallpaper-engine RPM installation has known Atomic/immutable friction. | Avoid unreviewed runtime source builds or mutable post-install package installation. | Do not add Wallpaper Engine integration as a default image feature. |

### Quickshell, Niri, and Dotfile References

| Source | License or status | Finding | Reusable lesson | Decision |
| --- | --- | --- | --- | --- |
| [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) | GitHub topic discovery; detailed license review pending | A large usability-first Quickshell Material configuration. | Cover a session as a coherent whole: shell, launcher, terminal, wallpaper, and editor. | Idea already applied through native variant overlays. Do not copy Hyprland configuration. |
| [caelestia-dots/shell](https://github.com/caelestia-dots/shell) | GitHub topic discovery; detailed license review pending | A fluid Quickshell desktop shell with strong dynamic visual cohesion. | Keep shell-level dynamics inside the shell that owns them. | Do not add a third Niri shell beside DMS and Noctalia. |
| [Noctalia](https://github.com/noctalia-dev/noctalia) | Existing selected component | A Wayland shell that supports Niri and dynamic wallpaper palettes. | Native wallpaper palette ownership is preferable to external synchronization scripts. | Already selected for `niri-noctalia`; do not add an overlapping wallpaper manager. |
| [prasanthrangan/hyprdots](https://github.com/prasanthrangan/hyprdots) | GitHub topic discovery | Dynamic, minimal Hyprland configuration with broad surface coverage. | A complete polish pass includes terminals, launchers, media, OSD, and lock/login surfaces. | Coverage checklist reference only; implementation remains compositor-native. |
| [mylinuxforwork/dotfiles](https://github.com/mylinuxforwork/dotfiles) | GitHub search result | Demonstrates wallpaper backend migrations and the failure modes of dynamic wallpaper stacks. | A wallpaper backend is an integration boundary, not a cosmetic utility. | Do not layer it over DMS or Noctalia. |
| `skwd-wall`, Tide Island, and other Niri/Quickshell topic results | Discovery-only | Wallpaper selectors, interactive islands, and custom panels appeared in current topic searches. | Their visual ideas are shell-specific and require their own state, IPC, and update surface. | Not selected because DMS and Noctalia already provide these roles. |
| `omadora`, personal Niri/Hyrpland dotfiles, and small rice repositories | Discovery-only | Fedora and Arch rice repositories show many tightly coupled installer scripts. | Avoid personal paths, monolithic installers, and desktop-specific assumptions in the product image. | No source or asset reuse. |

### KDE Plasma References

| Candidate | License or status | Finding | Integration value | Decision |
| --- | --- | --- | --- | --- |
| [KDE Material You Colors](https://github.com/luisbocanegra/kde-material-you-colors) | GPL-3.0, active | Generates Plasma color schemes from wallpaper and provides a Plasma widget/automation workflow. | Could give the KDE-only image wallpaper-driven Plasma colors while keeping the default wallpaper blue. | Experimental KDE-only candidate. Requires Fedora 44 packaging review, user service lifecycle, wallpaper-change behavior, rollback, and VM QA before enabling. |
| [Klassy](https://github.com/paulmcauley/klassy) | License review required before reuse; current Plasma 6 releases found | A highly customizable Plasma window decoration, application style, and global-theme plugin. | Could improve titlebar geometry and density. | Do not default-enable: it changes core Plasma rendering and needs version-locked binary compatibility testing. |
| [Darkly](https://github.com/Bali10050/Darkly) | Active; GitHub metadata `NOASSERTION` | A Lightly-derived application style and window decoration with Fedora source-build instructions. | Provides rounded corners, floating titlebar options, and transparency controls. | Reject as a base-image default until license and Fedora packaging are established. Source builds increase immutable-image maintenance cost. |
| NoxForge, Wisteria, vinyl-theme, cherry-kde, LichArch, and bitpunk-theme | Topic-search discovery only | Current Plasma-theme topic results included industrial, flat, cyberpunk, and Arch-specific complete themes. | Confirms the value of consistent terminal, boot, login, and desktop surfaces. | No direct reuse. These projects have unrelated visual identities, unclear packaging, or single-user assumptions. |
| KDE native effects and panel settings | Native platform capability | Plasma can supply blur, panel opacity, titlebar geometry, and animation settings without external code. | Small native adjustments may be safer than global-theme plugins. | Future KDE-only refinement candidate after a graphical Plasma VM review. Do not enable blur by default without readability QA. |

### GNOME References

| Candidate | License or status | Finding | Integration value | Decision |
| --- | --- | --- | --- | --- |
| [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) | LGPL-2.1, active | A libadwaita-derived GTK3 theme that aligns legacy GTK3 apps with GNOME/libadwaita. Fedora 44 provides `adw-gtk3-theme` version `6.4-3.fc44`. | Directly improves GTK3 consistency and is the official DMS prerequisite for its managed GTK theme path. | Highest-priority candidate, initially for `niri-dms` only. |
| [Blur my Shell](https://github.com/aunetx/blur-my-shell) | GNOME extension; license and Fedora packaging must be verified before shipping | Adds blur to the GNOME top panel, dash, and overview. | Visual impact is high but it changes Shell rendering and can interact with other extensions. | Do not default-enable. It conflicts with the current restrained, high-legibility visual contract and creates GNOME Shell extension maintenance work. |
| Bar Enhanced and Open Bar search results | Discovery-only; source/license/package status not established in this pass | Alternative top-bar styling and adaptive visual controls. | Could alter panel hierarchy. | Do not select without a clear upstream, license, and GNOME-version compatibility matrix. |
| [MoreWaita](https://github.com/somepaulo/MoreWaita) | GPL-3.0, active | Expanded Adwaita-style icons for third-party applications and MIME types. | Strong GNOME-adjacent icon improvement without replacing the shell or toolkit. | Recommended as an optional, user-selectable icon theme after packaging and attribution work. Keep Papirus Dark as the default until cross-desktop visual QA is complete. |
| Colloid, Orchis, and other GTK-theme results | Search discovery only | Themed GTK packages and colorizers exist, including Matugen-oriented forks. | They demonstrate demand for GTK3 compatibility layers. | Do not add: direct GTK stylesheet ownership would conflict with DMS generation or GNOME native preferences. |

### Icon Theme References

| Candidate | License or status | Finding | Decision |
| --- | --- | --- | --- |
| [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) | Existing Fedora package; actively maintained upstream | Includes dark/light variants, KDE color-scheme integration, folder color support, tray support, and broad application coverage. | Keep as the default cross-desktop icon theme. |
| [MoreWaita](https://github.com/somepaulo/MoreWaita) | GPL-3.0, active | Complements Adwaita with third-party application and MIME coverage. | Preferred optional GNOME-adjacent icon addition. Requires source lock, license text, attribution, and packaging plan. |
| [Tela](https://github.com/vinceliuice/Tela-icon-theme) | GPL-3.0, active | Flat icon theme with a blue folder-color variant that matches the SoltrOS accent. | Optional KDE/Niri-oriented alternative. Do not ship as a second default together with MoreWaita. |
| Paper Icon Theme, Numix Circle, and Luv | Discovery-only | Additional current icon-theme topic candidates. | No selection: Paper is much less current; Numix and Luv do not improve the existing Papirus/MoreWaita decision enough to justify more payload. |

### DMS, Qt, Browser, and Terminal References

| Candidate | License or status | Finding | Decision |
| --- | --- | --- | --- |
| [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell) | MIT, active | Current official docs describe generated GTK, Qt, terminal, editor, and browser outputs. GTK integration explicitly recommends Fedora `adw-gtk3-theme`. | Existing selected shell. Extend only through its documented generated-file interfaces. |
| `adw-gtk3-theme` | Fedora 44 package confirmed | DMS can manage GTK links after the package is present; generated colors change with wallpaper/theme selection. | Implement first in `niri-dms`, but verify the supported DMS setting schema in an image session before pre-seeding any user preference. |
| Qt6CT / `qt6ct-kde` | Main `trialuser02/qt6ct` metadata shows archived; the KDE fork packaging route is not established | DMS documents Qt6CT as an advanced route and warns that standard Qt6CT can render Dolphin poorly without `qt6ct-kde`. | Defer. Do not export global Qt platform theme variables, which can break Plasma. |
| [Kvantum](https://github.com/tsujan/Kvantum) | Active; Fedora package pages exist | SVG-based Qt theme engine for Qt/KDE/LXQt. | Defer. It is useful only with a complete Qt ownership plan and must not be forced globally. |
| [Pywalfox](https://github.com/Frewacom/pywalfox) | MPL-2.0, active | Dynamic Firefox/Thunderbird colors; DMS generates a Pywalfox-compatible color artifact. | Optional DMS experiment only. SoltrOS distributes Waterfox, so profile discovery, native messaging, add-on policy, and rollback must be proven first. |
| Material Fox search result | Discovery-only | DMS documentation describes a Firefox profile CSS route. | Not selected because the product browser is Waterfox and the profile-level behavior has not been verified. |
| [Ghostty](https://github.com/ghostty-org/ghostty) | MIT, active | GPU-accelerated terminal; DMS documents generated Ghostty theme support. | Optional terminal only. Kitty and Alacritty already provide complete defaults, so do not replace them or expand the base image without a user-facing reason. |
| [Yazi](https://github.com/sxyazi/yazi) | MIT, active | Fast terminal file manager with a theme/plugin system, image preview integration, and optional ripgrep/fd/fzf/zoxide workflow. | Recommended shared optional tool, pending Fedora 44 package verification and a minimal original SoltrOS configuration. |
| Mission Center, nvtop, MangoHud, GOverlay | Existing components | Graphical and terminal monitoring/game overlay capability is already present. | Do not add a duplicate monitoring stack. |

### Wallpaper and Dynamic-Color Tool References

| Candidate | License or status | Finding | Decision |
| --- | --- | --- | --- |
| [Waypaper](https://github.com/anufrievroman/waypaper) | GPL-3.0, active | GUI wallpaper frontend that supports multiple backends including swaybg, awww, swww, and mpvpaper. | Do not add by default. It would compete with DMS and Noctalia wallpaper ownership. |
| [swww](https://github.com/LGFae/swww) | GPL-3.0; GitHub repository is archived | Animated Wayland wallpaper daemon. | Reject. It is archived and would replace the intentionally simple `swaybg` path. |
| `awww` | Current successor mentioned by Wayland/Hyrpland ecosystem search results | Animated wallpaper backend that replaced swww in some distributions. | Do not add. It has the same ownership conflict and would require DMS/Noctalia event integration. |
| `wbg`, `swaybg`, `mpvpaper`, wallpaper-engine frontends | Discovery-only | Static, animated, and video wallpaper alternatives. | Retain `swaybg` for the shared Niri baseline. Avoid video/animated wallpaper defaults due GPU cost, desktop ownership conflict, and image complexity. |
| Matugen-oriented wallpaper selectors such as `skwd-wall` | Discovery-only | Can generate palettes from images/video/Wallpaper Engine scenes. | Not selected because both Niri shells already have dedicated palette owners. |

## Candidate Ranking

### Approved-by-Design, Awaiting User Approval

#### 1. DMS GTK3 Completion

**Candidate:** Fedora `adw-gtk3-theme` in the `niri-dms` image.

**Why it is first:** It completes an existing DMS feature path instead of adding
a competing visual framework. The package is explicitly documented by DMS for
GTK theming and is confirmed in Fedora 44.

**Expected result:** GTK3 applications in the DMS variant follow the DMS
generated dark Material palette more consistently while GTK4/libadwaita,
Kitty, and Alacritty retain their current native paths.

**Scope:** Niri + DMS only. GNOME, KDE, and Niri + Noctalia retain their
current Adwaita/Breeze/Noctalia ownership.

**Risks:** DMS settings must be discovered in the actual image before a
default is written. DMS generated files must not be vendored or pre-created in
`/etc/skel`. The result requires a disposable Niri + DMS graphical session
for verification.

#### 2. Yazi as a Shared Explicit Terminal Tool

**Candidate:** Yazi plus a small original SoltrOS dark-blue configuration.

**Why it is second:** It improves the actual terminal workflow across all
four variants without replacing a graphical file manager, shell, or portal.

**Expected result:** A visually coherent, fast terminal file manager that
works from Konsole, Kitty, and Alacritty. It remains an explicit `yazi`
command and does not alter file associations or default file choosers.

**Risks:** Fedora 44 availability and preview dependencies must be checked in
the build container. Plugins/themes must not be fetched at image runtime, and
third-party configuration should not be copied without a license review.

#### 3. Optional Icon Theme Choice

**Candidate:** MoreWaita first; Tela Blue only as an alternative decision.

**Why it is third:** It adds visible user choice without destabilizing native
desktop shells. MoreWaita improves GNOME-adjacent app and MIME coverage;
Tela offers blue folders aligned with the SoltrOS accent.

**Expected result:** Papirus Dark remains the deterministic default. A user
can choose one additional icon theme through a native desktop setting or a
future graphical settings page.

**Risks:** Both candidates are GPL-3.0. Bundling requires source provenance,
license text, attribution, update policy, package integrity metadata, and
cross-desktop visual checks. This is not a package-name-only change.

### Experimental, Not Default

#### 4. KDE Material You Colors

This can be valuable for users who want Plasma colors to follow their chosen
wallpaper, but it should be a KDE-only opt-in. It must not run globally, must
not alter the other images, and must include daemon lifecycle and rollback
coverage. The existing blue Breeze Dark configuration remains the default.

#### 5. Waterfox Dynamic Theme Integration

Pywalfox is a viable DMS source, but only after Waterfox compatibility is
verified with a disposable profile. The default browser must continue working
without an add-on, native-messaging host, or profile stylesheet.

#### 6. Ghostty

Ghostty can be a well-integrated optional terminal, especially for DMS users,
but current Kitty and Alacritty coverage means that a third default terminal
would add image size and support overhead without solving a current gap.

### Not Selected

- Qt6CT/Kvantum as a global solution: insufficiently safe for Plasma and
  unresolved `qt6ct-kde` packaging.
- Darkly and Klassy as default Plasma styles: require binary/plugin and
  license/package lifecycle work.
- Blur My Shell, Open Bar, and other GNOME Shell replacements: visual effect
  does not justify GNOME extension compatibility maintenance in the default
  image.
- Waypaper, swww, awww, video wallpaper, or Wallpaper Engine defaults: they
  conflict with DMS/Noctalia wallpaper ownership or add GPU/runtime overhead.
- Copying complete dotfile repositories: they are compositor-, user-, path-,
  and asset-specific rather than reusable system defaults.

## Best-Practice Implementation Plan

This plan starts only after explicit user approval. Each phase is independently
reviewable and can be stopped without changing later phases.

### Phase 0: Preflight for Every Approved Candidate

1. Verify Fedora 44 package availability inside the target build environment.
2. Record exact package version, repository origin, upstream source, license,
   and update mechanism in the private research ledger.
3. Add no source artifact unless its license, provenance, and redistribution
   requirements are recorded.
4. Keep every package and overlay variant-scoped unless a shared behavior is
   demonstrably useful in all four images.
5. Add a focused source contract before changing a package layer or service.

### Phase 1: DMS GTK3 Completion

1. Add `adw-gtk3-theme` only to the Niri + DMS desktop package stage.
2. Inspect the installed DMS version in a disposable image for its supported
   setting interface; use the documented native setting rather than manually
   linking generated CSS in SoltrOS code.
3. Preserve the existing DMS one-shot palette helper and marker behavior.
4. Add contracts that assert variant isolation and package presence without
   executing real DMS generation on the development host.
5. Build the Niri + DMS image and perform a disposable graphical QA session:
   first login, wallpaper source, DMS palette completion, GTK3 application,
   GTK4/libadwaita application, Kitty, Alacritty, launcher, lock screen,
   logout/login, and custom-wallpaper behavior.
6. Roll back by removing the package and DMS-setting overlay in a follow-up
   image commit; no generated per-user files are tracked by the image.

### Phase 2: Yazi

1. Verify the Fedora 44 package and decide the smallest preview dependency
   set compatible with the existing image size policy.
2. Add a minimal original configuration under the shared user-default overlay.
   Do not import third-party Yazi themes or plugins without their own review.
3. Keep `yazi` explicit: no MIME, portal, desktop-entry, Nautilus, or Dolphin
   replacement.
4. Test configuration parsing, launch from Konsole/Kitty/Alacritty, directory
   exit behavior, basic preview fallback, and user-default migration.
5. Roll back by removing the package and configuration; existing graphical
   file-manager behavior remains unchanged.

### Phase 3: Optional Icon Theme

1. Choose exactly one first candidate: MoreWaita or Tela Blue.
2. Prefer a Fedora package when available. If bundling is necessary, create a
   source lock, attribution notice, license copy, integrity record, and a
   deterministic update procedure before importing assets.
3. Expose the theme as optional. Keep Papirus Dark as the initial default.
4. Verify GTK3, GTK4, GNOME Shell, Plasma, Niri launchers, file-manager MIME
   icons, Flatpak applications, and fallback behavior when an icon is absent.
5. Roll back by removing the optional selection and payload without changing
   the Papirus default.

### Phase 4: Experimental KDE and Browser Work

1. Prototype KDE Material You Colors only in an isolated KDE build branch and
   disposable VM session.
2. Verify background changes, color scheme generation, Plasma panel/widget
   behavior, Konsole, Flatpak applications, logout/login, and user rollback.
3. Prototype Pywalfox only in a disposable Waterfox profile. Verify extension
   behavior, native host lifecycle, browser startup, uninstall, and profile
   recovery before it can be offered as opt-in.
4. Consider Ghostty only after a documented reason to add a third terminal and
   a Fedora 44 package-source review.

## Approval Bundles

| Bundle | Contents | Recommendation |
| --- | --- | --- |
| A | DMS GTK3 Completion only | Recommended first implementation. It closes a documented DMS integration gap with the lowest architectural risk. |
| B | Bundle A plus Yazi | Recommended after Fedora 44 package verification. It adds a shared terminal workflow without changing graphical defaults. |
| C | Bundle B plus optional MoreWaita research/packaging | Good next step, but do not change the default icon theme. |
| D | KDE Material You Colors, Pywalfox, or Ghostty experiments | Separate opt-in prototypes only; do not combine with the baseline polish commit. |

## Required Evidence Before Delivery

- `git diff --check` and the required repository language scan pass.
- Every changed shell script passes syntax validation.
- Desktop contracts prove variant isolation and no accidental DMS execution on
  the host.
- Package installation is proven in Fedora 44, not inferred from this host.
- The affected image boots in a disposable VM.
- The user-facing graphical path is observed for the affected desktop variant.
- Static, runtime, and visual QA are reported separately.
- Any source payload has license, attribution, provenance, integrity, update,
  and rollback records.
