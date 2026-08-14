# SoltrOS Reborn - Desktop Edition

![SoltrOS Screenshot](https://github.com/Soltros-OS-Reborn/Soltros-OS-Reborn/blob/main/screenshots/Screenshot%20From%202025-07-03%2004-33-37.png?raw=true)

> SoltrOS Reborn is the continuation of the discontinued SoltrOS project. It provides Fedora 44 bootc images with the same gaming, MacBook, and developer foundations and four independently built desktop variants.

Project repository: [Soltros-OS-Reborn/Soltros-OS-Reborn](https://github.com/Soltros-OS-Reborn/Soltros-OS-Reborn)

Official SoltrOS Reborn images are published from this repository to the public
`ghcr.io/soltros-os-reborn` namespace. The signed `stable` channel is the
recommended installation and update source.

A gaming-optimized immutable Linux distribution based on Fedora bootc images, featuring MacBook hardware support, gaming enhancements, CachyOS kernel performance, and developer-friendly tools. Each desktop variant is built as a separate image so the immutable system never carries a second display manager or desktop stack.

## Desktop Variants

| Variant | Official OCI image | Session and login path |
| --- | --- | --- |
| KDE Plasma | `ghcr.io/soltros-os-reborn/soltros-os:stable` | Plasma Login Manager |
| GNOME | `ghcr.io/soltros-os-reborn/soltros-os-gnome:stable` | GDM |
| Niri + Dank Material Shell | `ghcr.io/soltros-os-reborn/soltros-os-niri-dms:stable` | greetd and DMS |
| Niri + Noctalia | `ghcr.io/soltros-os-reborn/soltros-os-niri-noctalia:stable` | greetd and Noctalia |

The source of truth for these variants is [`variants/desktop-variants.json`](variants/desktop-variants.json). CI builds, smoke-tests, signs, and publishes every entry through the channels defined in [`release/release.json`](release/release.json).

*Inspired by [VenOS](https://github.com/Venefilyn/veneos) - bringing together the best of gaming and productivity.*

# Signing Key Rotation Notice

The Reborn project uses its own signing key and does not trust the discontinued
project's key. The current public-key SHA-256 fingerprint is:

```text
e1c573c15443f249a0603c83d71658737ab00e2d2c8e7c667f378f7972ad557b
```

Systems created from an earlier development image must refresh both trust files
before switching to an official channel.

### 1. Download the public key
```bash
sudo mkdir -p /etc/pki/containers
sudo curl --fail --location --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/Soltros-OS-Reborn/Soltros-OS-Reborn/main/soltros.pub \
  --output /etc/pki/containers/soltros.pub
```
### 2. Download the secure policy
```bash
sudo mkdir -p /etc/containers
sudo curl --fail --location --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/Soltros-OS-Reborn/Soltros-OS-Reborn/main/resources/policy.json \
  --output /etc/containers/policy.json
```
### 3. Verify permissions
```bash
sudo chmod 644 /etc/pki/containers/soltros.pub
sudo chmod 644 /etc/containers/policy.json
test "$(sha256sum /etc/pki/containers/soltros.pub | awk '{print $1}')" = \
  e1c573c15443f249a0603c83d71658737ab00e2d2c8e7c667f378f7972ad557b
```

## 🚀 Features

### 🎮 Gaming Ready
- **CachyOS kernel** for up to 15% better gaming performance with optimized scheduler
- **Gaming optimizations** with enhanced kernel parameters for performance
- **Controller support** for PlayStation, Xbox, Nintendo Switch Pro, Steam, and 8BitDo controllers
- **MangoHud** and **GameMode** integration for performance monitoring and optimization
- **Steam runtime optimizations** with proper GPU configurations
- **Optimized CPU governor** settings for gaming workloads

### 💻 MacBook Support
- **Thermal management** with `thermald` and `mbpfan` for optimal temperature control
- **Apple SMC support** via `applesmc` kernel module
- **Hardware-specific configurations** optimized for MacBook Pro models
- **Humidity-resistant thermal settings** for better longevity

### 📦 Quadruple Package Management
- **RPM-OSTree** (System packages) - Immutable base system
- **Flatpak** (Applications) - Sandboxed desktop applications
- **Distrobox** (Development tools) - Containerized development environments
- **Homebrew** (Additional tools) - macOS-style package manager for Linux
- **Nix** (Additional tools) - NixOS package manager for access to a wide variety of applications and tools

### 🛠️ Developer Experience
- **Zsh shell** as default with modern tooling integration
- **SoltrOS command runner** with extensive system management capabilities
- **Git integration** with SSH signing and useful aliases
- **Shell enhancements** with aliases, plugins, and modern CLI tools
- **Container signing** with cosign for security

### 🎨 Desktop Environment
- Four isolated desktop images: KDE Plasma, GNOME, Niri + Dank Material Shell, and Niri + Noctalia
- A variant-specific display manager: Plasma Login Manager, GDM, or greetd
- **Papirus icon theme** for a modern look
- **Custom branding** and SoltrOS identity
- **Optimized settings** for productivity and aesthetics

## 📋 Included Software

### System Packages (RPM)
- `Zsh` - Modern shell with many plugins
- `gimp` - Image editing
- `tailscale` - Zero-config VPN
- `gamemode` & `mangohud` - Gaming performance tools
- `papirus-icon-theme` - Modern icon set
- `thermald` & `mbpfan` - Thermal management
- `lm_sensors` - Hardware monitoring
- `kernel-cachyos` - High-performance gaming kernel

### Flatpak Applications
Over 40 pre-configured applications including:
- **Browsers**: Waterfox
- **Communication**: Discord, Telegram
- **Media**: VLC, Jellyfin Media Player, Clapper
- **Gaming**: Steam, Lutris, RetroArch, Heroic Games Launcher
- **Development**: Zed Editor, Podman Desktop
- **Productivity**: LibreOffice, Bitwarden
- **System Tools**: Flatseal, Mission Center, Warehouse

### Development Tools (Available via Distrobox)
Access to any Linux distribution's packages via containerized environments - all without affecting the base system.

## 🚀 Quick Start

### Installation

#### Method 1: Rebase from existing Fedora Atomic

Install the Reborn signing key and policy from the rotation notice above, then
select exactly one desktop image:

```bash
# KDE Plasma
sudo bootc switch ghcr.io/soltros-os-reborn/soltros-os:stable

# GNOME
sudo bootc switch ghcr.io/soltros-os-reborn/soltros-os-gnome:stable

# Niri + Dank Material Shell
sudo bootc switch ghcr.io/soltros-os-reborn/soltros-os-niri-dms:stable

# Niri + Noctalia
sudo bootc switch ghcr.io/soltros-os-reborn/soltros-os-niri-noctalia:stable
```

Reboot after the selected command succeeds:

```bash
sudo systemctl reboot
```

The system records the selected image as its signed update source. Use
`soltros status`, `soltros update`, and `soltros rollback` for normal lifecycle
operations.

#### Method 2: Fresh Installation
The LiveISO provides a complete offline KDE live desktop and embeds all four
desktop variants. Network access is optional and updates the selected image only
after explicit user consent. After installation, the selected system starts the
Welcome to SoltrOS application at the user's first graphical login.

### First-login Setup

Welcome to SoltrOS provides a native GTK setup flow shared by KDE Plasma, GNOME,
Niri with Dank Material Shell, and Niri with Noctalia. It can configure an
optional Git identity, preserve or change the login shell, and install selected
software profiles. Network-dependent choices start disabled when the system is
offline, and all downloadable profiles remain off until the user selects them.

The setup app records completion only after every selected task succeeds. Failed
tasks remain available for retry, and **Set Up Later** stops automatic launch
without preventing the app from being reopened from the application menu or with:

```bash
soltros-welcome
```

Automatic launch is enabled only for systems installed by a compatible SoltrOS
installer. Existing systems that receive the application through an update do
not unexpectedly enter the first-login flow.

## 🛠️ Available Commands

SoltrOS includes a command dispatcher for system management:

### Installation & Setup
```bash
soltros install                  # Install all SoltrOS components
soltros install-flatpaks         # Install all Flatpak applications
soltros install-dev-tools        # Install development tools
soltros install-gaming           # Install gaming applications
soltros install-multimedia       # Install multimedia tools
soltros setup-cli                # Setup shell configurations
soltros setup-git                # Configure Git with SSH signing
soltros setup-distrobox          # Setup development containers
soltros install-homebrew         # Setup the Homebrew package manager
soltros install-nix              # Setup the Nix package manager
soltros install-oh-my-zsh        # Setup Oh My Zsh plugins and tools
soltros change-to-zsh            # Switch the current user from Bash to Zsh
```

### System Configuration
```bash
soltros enable-amdgpu-oc         # Enable AMD GPU overclocking
soltros toggle-session           # Toggle between X11 and Wayland
```

### System Management
```bash
soltros update                   # Update the system, Flatpaks, and containers
soltros clean                    # Clean up the system
soltros help                     # Show all available commands
```

## 🔧 Customization

### Shell Configuration
SoltrOS automatically sets up:
- **Fish shell** with modern plugins
- **Aliases** for common tools (eza, bat, flatpak apps)
- **Environment variables** for optimal development experience
- **Tool integrations** for starship, atuin, zoxide, etc.

### Gaming Optimizations
Pre-configured settings include:
- CachyOS kernel with gaming-optimized scheduler
- Increased memory map areas (`vm.max_map_count = 2147483642`)
- Network optimizations for online gaming
- Controller udev rules for proper access
- CPU performance governor settings

### MacBook Optimizations
- Aggressive thermal management starting at 58°C
- Hardware sensor support via applesmc
- Optimized fan curves for humidity resistance

## 🔒 Security

- **Container signing** with cosign verification
- **Immutable base system** via rpm-ostree
- **Sandboxed applications** via Flatpak
- **Containerized development** via Distrobox
- **Verified package sources** for all package managers

## 🏗️ Building

### Prerequisites
- Podman or Docker

### Build locally
```bash
just build-image kde
just build-image gnome
just build-image niri-dms
just build-image niri-noctalia
```

### Build the LiveISO
```bash
disk_config/build-live-iso.sh output/liveiso
```

Release builds use `xz` SquashFS compression. For faster local LiveISO QA, set
`LIVEISO_COMPRESSION=zstd`; the resulting media has the same runtime and
installer behavior but uses more disk space.

The LiveISO is a complete KDE live environment with all four deduplicated bootc
payloads embedded for offline installation. An optional update is offered only
after network and signature preflight succeeds and remains disabled by default.
Recovery details are in [`docs/installer-recovery.md`](docs/installer-recovery.md),
and the gated publication procedure is in [`docs/release.md`](docs/release.md).

## Server Image
The SoltrOS Server Edition is still a work in progress. Server work will be tracked in this repository as the Reborn project develops.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the build locally
5. Submit a pull request

## 📝 License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [VenOS](https://github.com/Venefilyn/veneos) for the inspiration and innovative approach to immutable gaming distributions
- [Universal Blue](https://github.com/ublue-os) for the excellent foundation
- [Fedora Project](https://fedoraproject.org/) for the underlying OS
- [CachyOS](https://cachyos.org/) for the high-performance kernel
- [NixOS](https://nixos.org/) for the top-of-the-line package manager

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/Soltros-OS-Reborn/Soltros-OS-Reborn/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Soltros-OS-Reborn/Soltros-OS-Reborn/discussions)

---

**SoltrOS Reborn** - Gaming meets productivity in an immutable, secure, and developer-friendly Linux distribution.
