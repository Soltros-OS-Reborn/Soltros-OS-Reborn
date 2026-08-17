# Desktop Polish Contract

## Visual Direction

SoltrOS Reborn defaults to a dark, high-contrast desktop with a blue accent.
Neutral charcoal surfaces provide the base hierarchy, blue is reserved for
interactive focus and selected state, and red remains reserved for urgency.
This keeps gaming, developer, and configuration surfaces readable without
turning every surface into an accent color.

| Role | Value | Use |
| --- | --- | --- |
| Base | `#14161b` | Workspace and terminal background |
| Raised surface | `#20242d` | Inactive chrome and terminal black |
| Accent | `#4c9aff` | Focus, selection, active state |
| Accent support | `#2779d9` | Wallpaper structural detail |
| Primary text | `#dce2eb` | Standard foreground |
| Urgency | `#ff6b81` | Urgent window and error state |

## Shared Defaults

- The generated SoltrOS Electric Blue wallpaper is the only new graphic asset.
  It is maintained in this repository as SVG and a generated 1920x1080 PNG.
- `Papirus-Dark` is selected through the Fedora `papirus-icon-theme` package
  already layered by the common image. No icon payload is copied from a
  third-party checkout.
- GTK 3 and GTK 4 applications default to dark appearance, the Papirus Dark
  icon set, and the Adwaita 24-pixel cursor.
- Starship uses a compact, original blue-accent prompt with directory, Git,
  command-duration, and exit-state information. Fastfetch is installed with a
  compact, ASCII-safe system summary for on-demand use; it is not run
  automatically when a terminal opens.
- JetBrains Mono is provided by Fedora for terminal text. GNOME, Konsole,
  Alacritty, the DMS-provided Kitty profile, and the Niri quick launcher use
  it through their native configuration surfaces.
- `btop` receives a shared dark-blue theme with readable data-oriented color
  gradients while keeping the active terminal background visible.
- Existing user configuration remains authoritative. Versioned user defaults
  copy a new file only when it is absent or unchanged from the previous
  SoltrOS version; modified files are retained beside a `.soltros-new` copy.

## Variant Ownership

### KDE Plasma

- Breeze Dark remains the native Plasma global theme.
- KDE globals select Papirus Dark, an Adwaita cursor, and blue active-window
  colors.
- Konsole receives the SoltrOS terminal profile. A one-shot KDE autostart task
  applies the branded wallpaper and removes its own user-level autostart entry.

### GNOME

- The system dconf database sets `prefer-dark`, the GNOME blue accent, Papirus
  Dark, the Adwaita cursor, and the branded light and dark wallpaper URI.
- The wallpaper is registered with GNOME Backgrounds so it remains discoverable
  and replaceable in Settings.
- The native libadwaita OOBE inherits this system preference and accent.

### Niri + Dank Material Shell

- Niri supplies the coherent dark workspace, blue focus treatment, a restrained
  one-pixel border and soft shadow, cursor, wallpaper, GTK defaults, and
  Alacritty colors.
- A one-shot user service invokes DMS's own `matugen generate` command from
  the SoltrOS wallpaper, selects dark mode and Papirus Dark, then records its
  completion. DMS remains the single owner of generated Material palettes.
- Kitty is installed for DMS as an optional terminal and imports DMS-generated
  colors and tab styling. The DMS-specific Alacritty entry point imports the
  same generated palette after the static fallback palette.
- SoltrOS does not vendor or overwrite DMS-generated configuration, terminal
  themes, or wallpaper state after that initial generation.

### Niri + Noctalia

- Niri shares the same workspace, focus treatment, border, shadow, cursor,
  wallpaper, GTK, and terminal base.
- `Mod+Shift+Space` opens the themed Fuzzel quick launcher. It supplements,
  rather than replaces, the native Noctalia launcher on `Mod+Space`.
- Noctalia starts in dark mode and extracts its native Material palette from
  the SoltrOS wallpaper directory. Its configuration is isolated from DMS.
- Users can select another wallpaper in Noctalia without changing the shared
  image defaults or DMS behavior.

## Verification Boundary

- The DMS palette generator is a first-login image service and writes
  DMS-owned output for the logged-in SoltrOS user. Automated host validation
  must not execute `dms matugen generate` against a developer session: DMS
  templates can use user-home output paths in addition to the explicit config
  and state directories.
- `tests/test-desktop-polish.sh` substitutes the `dms` command, uses temporary
  XDG roots, and verifies the generated command, one-shot marker, and explicit
  paths. Dynamic DMS output is verified only in a disposable Niri + DMS image
  session.

## Third-Party Boundary

The design research considered third-party OS configurations, icon themes,
and desktop automation projects. Their ideas informed architecture only. This
repository does not copy their theme code, wallpaper files, configuration
payloads, or branding. Fedora distributes Papirus as a package under its own
license metadata; the image selects that installed package rather than
redistributing an extracted copy.
