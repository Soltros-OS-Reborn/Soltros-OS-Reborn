# SoltrOS Reborn - Desktop Edition

![SoltrOS Screenshot](https://github.com/Soltros-OS-Reborn/Soltros-OS-Reborn/blob/main/screenshots/Screenshot%20From%202025-07-03%2004-33-37.png?raw=true)

> SoltrOS Reborn is the continuation of the discontinued SoltrOS project. This repository currently uses the original SoltrOS content as its baseline, retaining Fedora Bootc, KDE Plasma, gaming optimizations, MacBook support, and developer tools while continuing to improve and extend the system.

Project repository: [Soltros-OS-Reborn/Soltros-OS-Reborn](https://github.com/Soltros-OS-Reborn/Soltros-OS-Reborn)

Current container image: `ghcr.io/soltros-os-reborn/soltros-os-reborn:latest`

A gaming-optimized immutable Linux distribution based on Fedora Bootc's base image, featuring MacBook hardware support, gaming enhancements, CachyOS kernel performance, the KDE Plasma desktop environment, and developer-friendly tools.

*Inspired by [VenOS](https://github.com/Venefilyn/veneos) - bringing together the best of gaming and productivity.*

If you are using an RPM-OSTree based system like Fedora Silverblue, Bazzite, Bluefin, etc., you can use ``bootc`` to quickly swap to it.
```bash
sudo bootc switch ghcr.io/soltros-os-reborn/soltros-os-reborn:latest
sudo systemctl reboot
```

# NOTICE:
There has been an issue with policy.json not being generated correctly, resulting in an issue with bootc. This should now be fixed in future, fresh installed images as well as the ISO. However, if you are experiencing this issue on a current version of SoltrOS, please do the following or updating will not work:

### 1. Download the public key
```
sudo mkdir -p /etc/pki/containers
sudo curl -L https://github.com/Soltros-OS-Reborn/Soltros-OS-Reborn/raw/main/soltros.pub -o /etc/pki/containers/soltros.pub
```
### 2. Download the secure policy
```
sudo mkdir -p /etc/containers
sudo curl -L https://github.com/Soltros-OS-Reborn/Soltros-OS-Reborn/raw/main/resources/policy.json -o /etc/containers/policy.json
```
### 3. Verify permissions
```
sudo chmod 644 /etc/pki/containers/soltros.pub
sudo chmod 644 /etc/containers/policy.json
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
- **kde Desktop** with dark theme by default for lightweight performance
- **LightDM** display manager for fast boot times
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
```bash
sudo bootc switch ghcr.io/soltros-os-reborn/soltros-os-reborn:latest
```

#### Method 2: Fresh Installation
Use the provided ISO configuration to install directly.

### First Boot Setup

1. **Install Flatpaks**:
   ```bash
   sh /usr/share/soltros/bin/helper.sh install-flatpaks
   ```

2. **Setup development environment**:
   ```bash
   sh /usr/share/soltros/bin/helper.sh setup-cli
   ```

3. **Configure Git** (optional):
   ```bash
   sh /usr/share/soltros/bin/helper.sh setup-git
   ```

4. **Setup development containers** (optional):
   ```bash
   sh /usr/share/soltros/bin/helper.sh setup-distrobox
   ```

## 🛠️ Available Commands

SoltrOS includes a comprehensive helper script for system management:

### Installation & Setup
```bash
sh /usr/share/soltros/bin/helper.sh install                  # Install all SoltrOS components
sh /usr/share/soltros/bin/helper.sh install-flatpaks         # Install all Flatpak applications
sh /usr/share/soltros/bin/helper.sh install-dev-tools        # Install development tools
sh /usr/share/soltros/bin/helper.sh install-gaming           # Install gaming applications
sh /usr/share/soltros/bin/helper.sh install-multimedia       # Install multimedia tools
sh /usr/share/soltros/bin/helper.sh setup-cli                # Setup shell configurations
sh /usr/share/soltros/bin/helper.sh setup-git                # Configure Git with SSH signing
sh /usr/share/soltros/bin/helper.sh setup-distrobox          # Setup development containers
sh /usr/share/soltros/bin/helper.sh install-homebrew         # Setup MacOS style Brew package manager
sh /usr/share/soltros/bin/helper.sh install-nix              # Setup NixOS package manager via Determinite Systems tooling
sh /usr/share/soltros/bin/helper.sh install-oh-my-zsh        # Setup Oh My Zsh plugins/tools for Zsh
sh /usr/share/soltros/bin/helper.sh change-to-zsh            # Switch the current user from Bash to Zsh
sh /usr/share/soltros/bin/helper.sh download-zsh-configs     # Download Derrik's Zshrc config
```

### System Configuration
```bash
sh /usr/share/soltros/bin/helper.sh enable-amdgpu-oc         # Enable AMD GPU overclocking
sh /usr/share/soltros/bin/helper.sh toggle-session           # Toggle between X11 and Wayland
```

### System Management
```bash
sh /usr/share/soltros/bin/helper.sh update                   # Update the system (rpm-ostree, flatpaks, containers)
sh /usr/share/soltros/bin/helper.sh clean                    # Clean up the system
sh /usr/share/soltros/bin/helper.sh help                     # Show all available commands
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
podman build -t soltros-os .
```

### Run locally
```bash
podman run -it soltros-os
```

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
