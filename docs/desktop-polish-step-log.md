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
- [x] Add focused contract tests and validation.
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
| Terminal and Niri follow-up validation | Complete | 2026-08-17: Starship and Fastfetch rendered from the new shared defaults; both merged Niri variant configs passed `niri validate`; `tests/test-desktop-polish.sh` passed. | Full image builds remain intentionally deferred because the available `/home` capacity is insufficient for the four-image matrix. |
| Static and contract validation | Complete | Targeted shell, XML, TOML, INI, dconf, Niri, DMS, and overlay tests passed. Final `PYTHONDONTWRITEBYTECODE=1 just validate`, `git diff --check`, and the required Chinese-character scan passed after all refinements. | The contract test also verifies that variant overlays are applied before the DMS palette service is enabled. |
| DMS host-validation isolation | Complete | The DMS first-login helper is exercised with an exported test-double command and temporary XDG roots. | Automated validation asserts its exact DMS invocation, explicit paths, and one-shot state marker without invoking the host DMS templates. |
| Runtime visual QA | Partial | The generated wallpaper was visually inspected. Niri validates both DMS and Noctalia merged configurations; the KDE one-shot script was exercised in a disposable home and the DMS first-login interface is covered by a test double. | Full four-image builds and graphical VM sessions were not started because `/home` has 26 GiB free and is 95 percent full; dynamic DMS output and complete desktop-session evidence remain pending a disposable image session. |

## Design Constraints

- The default appearance is dark mode with a blue accent.
- Each desktop variant uses its native configuration mechanisms while sharing the same visual intent.
- Third-party assets are copied only after their license and attribution requirements are recorded.
- Existing user changes are preserved through the versioned user-default migration mechanism.
- Runtime evidence is recorded separately from static configuration validation.
