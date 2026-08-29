# Desktop Polish Step Log

## Scope

- [x] Update reference repositories with the shared safe updater.
- [x] Inventory third-party visual references and license obligations.
- [x] Define the shared dark-blue visual contract.
- [x] Apply KDE Plasma defaults.
- [x] Apply GNOME defaults.
- [x] Apply Niri + Dank Material Shell defaults.
- [x] Apply Niri + Noctalia defaults.
- [x] Integrate approved icon and theme assets.
- [x] Add or update user-default migration behavior.
- [x] Add shared terminal defaults.
- [x] Add Niri window depth defaults.
- [x] Audit and integrate reference desktop-tool strengths.
- [x] Complete DMS GTK3 theming with Fedora `adw-gtk3-theme`.
- [x] Add Yazi with an original SoltrOS configuration and preview support.
- [x] Add optional MoreWaita icons with source and license provenance.
- [x] Add focused contract tests and validation.
- [x] Add opt-in KDE Material You Colors with user-level rollback.
- [x] Add opt-in Waterfox Pywalfox native messaging for Niri + DMS.
- [x] Add opt-in Ghostty for Niri + DMS while preserving Kitty defaults.
- [~] Run image and runtime visual QA.

## Evidence Log

| Step | Status | Evidence | Notes |
| --- | --- | --- | --- |
| Repository update baseline | Complete | 2026-08-16: 42 repositories discovered below `/home/wangxianming/dev/OS`; 41 clean and `tools_and_themes/NyxNiri` has two pre-existing changes. | The shared updater will preserve dirty repositories and does not stash, reset, rebase, or push. |
| Disk capacity baseline | Complete | 2026-08-16: 27 GiB free on `/home`. | Full multi-variant image builds may require more temporary space; implementation and lightweight validation proceed first. |
| STEP LOG and private exploration ledger | Complete | Created `docs/desktop-polish-step-log.md` and the private state ledger. | The private ledger is outside the repository and is not eligible for Git publication. |
| Shared repository update | Complete with one external remote exception | 2026-08-16: `update-all-repos.sh` fetched 41 of 42 repositories, fast-forwarded 9, and confirmed 30 current. | It preserved two diverged references (`LanRhyme-dotfiles` and `NyxNiri`) and the two pre-existing `NyxNiri` worktree changes. `thirdparty_os/aldehyde-lx` was not updated because its configured `git@github.com:MrGrappleMan/aldehyde-lx.git` remote returned `Repository not found`; its local snapshot remains untouched. |
| Third-party visual inventory | Complete | Reviewed all 16 sibling OS projects and eight relevant tool, icon, theme, and dotfile references; the private ledger records source paths, license evidence, strengths, constraints, and decisions. | No third-party code, configuration, wallpaper, or branding was copied. Non-standard, absent, AGPL, and project-specific licenses were treated as no-reuse sources. |
| Shared visual contract | Complete | Added `docs/desktop-polish.md`, shared GTK 3/4 defaults, the SoltrOS Electric Blue SVG, and its generated 1920x1080 PNG. | Charcoal surfaces, a blue accent, `Papirus-Dark`, and an Adwaita 24-pixel cursor are the common baseline. |
| KDE Plasma defaults | Complete | Added Breeze Dark, Papirus Dark, cursor, Konsole, and one-shot wallpaper defaults in the KDE overlay. | The one-shot task removes its user autostart entry only after Plasma accepts the bundled wallpaper. |
| GNOME defaults | Complete | Added dark mode, GNOME blue accent, Papirus Dark, cursor, wallpaper URIs, and Backgrounds registration. | The dconf database compiles successfully. |
| Niri + DMS defaults | Complete | Added dark workspace, blue focus colors, cursor, wallpaper, Alacritty colors, and `soltros-dms-palette.service`. | A real isolated DMS run generated dark GTK, Niri, Kitty, Zed, and KDE-compatible palette outputs from the wallpaper with `#4c9aff` as source color; the completion marker prevents a second generation. |
| Niri + Noctalia defaults | Complete | Added dark Noctalia mode and native wallpaper-palette source configuration, isolated to the Noctalia overlay. | DMS and Noctalia configuration remains separate. |
| User-default migration | Complete | Expanded the migration source from Niri-only files to the complete variant `/etc/skel/.config` tree and bumped `user_defaults.version` to 3. | Existing customized files remain untouched and receive a `.soltros-new` candidate. |
| Shared terminal defaults | Complete | Added an original SoltrOS Starship palette and compact Fastfetch configuration to the shared overlay, added Fedora `fastfetch`, and bumped `user_defaults.version` to 4. | Starship inherits the existing shell integration. Fastfetch remains an explicit command so new terminals stay quiet. |
| Niri window depth | Complete | Added native one-pixel borders and restrained soft shadows to the shared Niri layout. | The existing blue focus ring remains the primary focus signal; border and shadow only separate adjacent windows from the dark workspace. |
| Reference-tool follow-up audit | Complete | Reviewed actual OS and theme files for terminal typography, launcher behavior, DMS Matugen output, btop themes, notifications, GTK CSS, and dynamic shell synchronization. | Direct GTK CSS, Mako, blur/glass effects, and shell-specific replacement scripts were not adopted because they would conflict with GNOME, DMS, or Noctalia ownership. |
| Typography and runtime-tool integration | Complete | Added Fedora `jetbrains-mono-fonts-all`, a DMS Kitty profile, an imported DMS Alacritty palette, a themed Fuzzel quick launcher, and a shared btop theme; bumped `user_defaults.version` to 5. | DMS users retain the shell's native terminal selection while gaining generated Kitty and Alacritty palettes. |
| DMS GTK3 completion | Complete | 2026-08-17: Fedora 44 package query confirmed `adw-gtk3-theme 6.4-3.fc44`; the package is scoped to `niri-dms`, and DMS v1.5.3 native settings are seeded for GTK theming, Papirus Dark, and dark terminals. | Generated DMS files remain runtime-owned. |
| Yazi terminal workflow | Complete | 2026-08-17: Yazi v26.8.15 release assets are source-locked for x86_64 and aarch64; the real x86_64 binary parsed and rendered the original SoltrOS config in a pseudo-terminal. | Yazi remains explicit and does not replace graphical file managers or MIME defaults. |
| Optional MoreWaita payload | Complete | 2026-08-17: MoreWaita commit `5438528502c6ee6473ede1087ed46c3872535f5f` is source-locked; GPL-3.0 license, README, and AUTHORS are installed alongside the theme. | Papirus Dark remains the default; native KDE, GNOME, and DMS settings can select MoreWaita. |
| Terminal and Niri follow-up validation | Complete | 2026-08-17: Starship and Fastfetch rendered from the new shared defaults; both merged Niri variant configs passed `niri validate`; `tests/test-desktop-polish.sh` passed; the niri-dms image build and runtime checks also passed. | The remaining three image builds and full graphical sessions are still separate capacity-controlled work. |
| Static and contract validation | Complete | Targeted shell, XML, TOML, INI, dconf, Niri, DMS, and overlay tests passed. Final `PYTHONDONTWRITEBYTECODE=1 just validate`, `git diff --check`, and the required Chinese-character scan passed after all refinements. | The contract test also verifies that variant overlays are applied before the DMS palette service is enabled. |
| KDE Material You Colors | Complete | 2026-08-17: KDE-only wheel and `materialyoucolor` source are locked with GPL license records; `/usr/bin/kde-material-you-colors` and `soltros-kde-material-you.service` are installed only in the KDE build path. | The service is disabled by default; `soltros-theme kde-material-you enable|disable` backs up and restores user KDE files. |
| Waterfox Pywalfox integration | Complete | 2026-08-17: Pywalfox native host `2.9.0` is MPL-2.0 and locked; only the Niri + DMS build installs the host and DMS exposes an explicit opt-in command. | The Waterfox extension remains a user choice and no profile or generated CSS is committed. |
| Ghostty integration | Complete | 2026-08-17: Ghostty `1.3.1`, upstream minisign metadata, and Zig `0.15.2` are source-locked; the DMS build compiles and verifies `/usr/bin/ghostty`. | Kitty remains the image default through `terminalOverride`; enable/disable only changes the current user's DMS settings with a backup. |
| DMS host-validation isolation | Complete | The DMS first-login helper is exercised with an exported test-double command and temporary XDG roots. | Automated validation asserts its exact DMS invocation, explicit paths, and one-shot state marker without invoking the host DMS templates. |
| Runtime visual QA | Partial | 2026-08-17: Built `localhost/soltros-reborn/soltros-os-niri-dms:polish-20260817` successfully (`BUILD_EXIT=0`, image ID `2b4191725777e0a4930227d989a845ac434ed5803461dc126f14e5507a4783ce`). Container checks confirmed Fedora `adw-gtk3-theme`, `ffmpegthumbnailer`, Yazi `26.8.15`, MoreWaita metadata, and DMS defaults; Yazi rendered in a real allocated pseudo-terminal and exited cleanly with `q`. | This is one-variant runtime evidence. Full four-image graphical VM sessions remain pending; Papirus Dark remains the image default while MoreWaita is optional. |
| Four-variant image evidence refresh | Partial | 2026-08-18: KDE `polish-kde5` (`2fe94681a418909dcb7cb61b19c8d7d1ff63ada2ffc06674289024fe0ad46f81`), GNOME `polish-gnome` (`7fcaf09e3f9cc70eea5edeadc5bb9de85d849d1627e1a27423b8246f6d62d79a`), and Niri + Noctalia `polish-noctalia` (`9972dc81056e3d9ec657c94769fdd9ba740ab06f7895c2ab1838993bd2ff2b70`) were built and passed their container contracts. | The current Niri + DMS rebuild reached the desktop stage but stopped because the pinned CachyOS kernel COPR and the DMS dependency COPRs returned repeated HTTP 504/timeout responses; no DMS image tag was produced. The source remains pinned to `kernel-cachyos` and no unavailable-package bypass was used. |
| DMS source and offline contract validation | Complete | 2026-08-18: `tests/test-desktop-polish.sh`, `./tools/validate-release.sh`, `just validate`, shell syntax checks, `git diff --check`, and the required Chinese-character scan all passed. | The DMS build remains a network-dependent runtime artifact; container and graphical QA are not claimed for this attempt because the required COPR packages were unavailable. |

## Design Constraints

- The default appearance is dark mode with a blue accent.
- Each desktop variant uses its native configuration mechanisms while sharing the same visual intent.
- Third-party assets are copied only after their license and attribution requirements are recorded.
- Existing user changes are preserved through the versioned user-default migration mechanism.
- Runtime evidence is recorded separately from static configuration validation.
