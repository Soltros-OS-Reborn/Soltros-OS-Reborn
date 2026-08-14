#!/usr/bin/env bash
# SoltrOS Setup Script
# Converted from justfile to standalone bash script

set -euo pipefail

SOLTROS_DATA_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOLTROS_DATA_DIR
SOURCE_LOCK="${SOLTROS_DATA_DIR}/sources.lock.json"
readonly SOURCE_LOCK

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

show_help() {
    cat << 'EOF'
SoltrOS Setup Script

Usage: soltros [COMMAND]

INSTALL COMMANDS:
  install                 Install all SoltrOS components
  install-flatpaks        Install Flatpak applications from bundled list
  install-dev-tools       Install development tools via Flatpak
  install-gaming          Install gaming tools via Flatpak
  install-multimedia      Install multimedia tools via Flatpak
  install-homebrew        Install the Homebrew package manager
  install-nix             Install the Nix package manager
  install-oh-my-zsh       Download and install the Oh My Zsh plugins/tools
  change-to-zsh           Swap shell to Zsh

SETUP COMMANDS:
  setup-git              Configure Git with user credentials and SSH signing
  setup-cli              Setup shell configurations and tools
  setup-distrobox        Setup distrobox containers for development

CONFIGURE COMMANDS:
  enable-amdgpu-oc       Enable AMD GPU overclocking support
  toggle-session         Toggle between X11 and Wayland sessions

OTHER COMMANDS:
  status                 Show the current bootc deployment and desktop variant
  update                 Update bootc, Flatpak applications, and containers
  rollback               Select the previous bootc deployment
  doctor                 Verify image, desktop, service, and trust contracts
  report                 Print a redacted diagnostic report
  clean                  Clean up the system
  distrobox              Manage distrobox containers
  toolbox                Manage toolbox containers

OTHER COMMANDS:
  help                   Show this help message
  list                   List all available commands

If no command is provided, the help will be shown.
EOF
}

list_commands() {
    echo "Available commands:"
    echo "  install install-flatpaks install-dev-tools install-gaming install-multimedia"
    echo "  setup-git setup-cli setup-distrobox"
    echo "  enable-amdgpu-oc toggle-session"
    echo "  status update rollback doctor report clean distrobox toolbox"
    echo "  help list"
}

download_verified() {
    local url="$1"
    local expected_sha256="$2"
    local output="$3"

    curl --fail --location --retry 3 --output "${output}" "${url}"
    printf '%s  %s\n' "${expected_sha256}" "${output}" | \
        sha256sum --check --status
}

ensure_flathub() {
    if ! flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
        print_error "Failed to add Flathub repository"
        return 1
    fi
}

# ───────────────────────────────────────────────
# INSTALL FUNCTIONS
# ───────────────────────────────────────────────

soltros_install() {
    print_header "Installing all SoltrOS components"
    soltros_install_flatpaks
}

soltros_install_flatpaks() {
    local flatpak_list="${SOLTROS_DATA_DIR}/flatpaks"

    print_header "Installing Flatpak applications from bundled list"

    if [[ ! -s "${flatpak_list}" ]]; then
        print_error "Flatpak application list not found: ${flatpak_list}"
        exit 1
    fi
    
    print_info "Setting up Flathub repository..."
    ensure_flathub
    
    print_info "Installing applications from bundled Flatpak list..."
    if xargs --no-run-if-empty -a "${flatpak_list}" flatpak --system -y install --reinstall; then
        print_success "Flatpaks installation complete"
    else
        print_error "Failed to install flatpaks"
        exit 1
    fi
}

install_dev_tools() {
    print_header "Installing development tools via Flatpak"

    ensure_flathub
    print_info "Installing development tools..."
    if flatpak install -y flathub \
        com.visualstudio.code \
        org.freedesktop.Sdk \
        org.freedesktop.Platform \
        com.github.Eloston.UngoogledChromium \
        io.podman_desktop.PodmanDesktop \
        com.jetbrains.IntelliJ-IDEA-Community; then
        print_success "Development tools installed!"
    else
        print_error "Failed to install development tools"
        exit 1
    fi
}

install_homebrew() {
    local commit expected_sha256 installer

    print_header "Setting up Homebrew"
    commit="$(jq -er '.homebrew_installer.commit' "${SOURCE_LOCK}")"
    expected_sha256="$(jq -er '.homebrew_installer.script_sha256' "${SOURCE_LOCK}")"
    installer="$(mktemp /tmp/soltros-homebrew-installer-XXXXXX)"
    trap 'rm -f "${installer}"' RETURN
    download_verified \
        "https://raw.githubusercontent.com/Homebrew/install/${commit}/install.sh" \
        "${expected_sha256}" "${installer}"
    if /bin/bash "${installer}"; then
        printf '%s\n' "eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\"" >> "${HOME}/.bashrc"
        print_success "Brew package manager installed!"
        echo "Please restart your terminal or run 'source ~/.bashrc' to use brew"
    else
        print_error "Failed to install the Brew package manager"
        exit 1
    fi
}

install_nix() {
    local installer expected_sha256

    print_header "Setting up Nix via Determinite Nix installer."
    installer=/nix/determinate-nix-installer.sh
    expected_sha256="$(jq -er '.nix_installer.script_sha256' "${SOURCE_LOCK}")"
    if [[ ! -f "${installer}" ]] ||
        ! printf '%s  %s\n' "${expected_sha256}" "${installer}" | sha256sum --check --status; then
        print_error "The pinned Nix installer is missing or invalid"
        exit 1
    fi
    if /bin/bash "${installer}" install; then
        print_success "Successfully installed and enabled the Nix package manager on SoltrOS."
    else
        print_error "Failed to install and enable the Nix package manager on SoltrOS."
        exit 1
    fi
}

setup_nixmanager() {
    print_success "nixmanager is already installed as /usr/bin/nixmanager"
}

install_oh_my_zsh() {
    local commit expected_sha256 installer

    print_header "Setting up Oh My Zsh!"
    commit="$(jq -er '.oh_my_zsh_installer.commit' "${SOURCE_LOCK}")"
    expected_sha256="$(jq -er '.oh_my_zsh_installer.script_sha256' "${SOURCE_LOCK}")"
    installer="$(mktemp /tmp/soltros-oh-my-zsh-installer-XXXXXX)"
    trap 'rm -f "${installer}"' RETURN
    download_verified \
        "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/${commit}/tools/install.sh" \
        "${expected_sha256}" "${installer}"
    if RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "${installer}"; then
        print_success "Oh My Zsh! installed."
    else
        print_error "Failed to install Oh My Zsh"
        exit 1
    fi
} 

change_to_zsh() {
    print_header "Changing shell to Zsh"
    if chsh -s /usr/sbin/zsh; then
        print_success "Changed from Bash to Zsh"
    else
        print_error "Failed to change from Bash to Zsh"
        exit 1
    fi
}

install_gaming() {
    print_header "Installing gaming applications via Flatpak"

    ensure_flathub
    print_info "Installing gaming applications..."
    if flatpak install -y flathub \
        com.valvesoftware.Steam \
        com.heroicgameslauncher.hgl \
        org.bottles.Bottles \
        net.lutris.Lutris \
        com.obsproject.Studio \
        com.discordapp.Discord; then
        print_success "Gaming setup complete!"
    else
        print_error "Failed to install gaming applications"
        exit 1
    fi
}

install_multimedia() {
    print_header "Installing multimedia applications via Flatpak"

    ensure_flathub
    print_info "Installing multimedia applications..."
    if flatpak install -y flathub \
        org.audacityteam.Audacity \
        org.blender.Blender \
        org.gimp.GIMP \
        org.inkscape.Inkscape \
        org.kde.kdenlive \
        com.spotify.Client \
        org.videolan.VLC; then
        print_success "Multimedia tools installed!"
    else
        print_error "Failed to install multimedia tools"
        exit 1
    fi
}

# ───────────────────────────────────────────────
# SETUP FUNCTIONS
# ───────────────────────────────────────────────

soltros_setup_git() {
    print_header "Setting up Git configuration"
    
    print_info "Setting up Git config..."
    read -r -p "Enter your Git username: " git_username
    read -r -p "Enter your Git email: " git_email

    git config --global color.ui true
    git config --global user.name "$git_username"
    git config --global user.email "$git_email"

    if [ ! -f "${HOME}/.ssh/id_ed25519.pub" ]; then
        print_info "SSH key not found. Generating..."
        ssh-keygen -t ed25519 -C "$git_email"
    fi

    print_info "Your SSH public key:"
    cat "${HOME}/.ssh/id_ed25519.pub"

    git config --global gpg.format ssh
    git config --global user.signingkey "key::$(cat "${HOME}/.ssh/id_ed25519.pub")"
    git config --global commit.gpgSign true

    print_info "Setting up Git aliases..."
    git config --global alias.add-nowhitespace '!git diff -U0 -w --no-color | git apply --cached --ignore-whitespace --unidiff-zero -'
    git config --global alias.graph 'log --decorate --oneline --graph'
    git config --global alias.ll 'log --oneline'
    git config --global alias.prune-all '!git remote | xargs -n 1 git remote prune'
    git config --global alias.pullr 'pull --rebase'
    git config --global alias.pushall '!git remote | xargs -L1 git push --all'
    git config --global alias.pushfwl 'push --force-with-lease'

    git config --global feature.manyFiles true
    git config --global init.defaultBranch main
    git config --global core.excludesFile "${HOME}/.gitignore"
    
    print_success "Git setup complete"
}

soltros_setup_cli() {
    print_header "Setting up shell configurations and tools"
    
    # Create necessary directories
    mkdir -p "${HOME}/.bashrc.d" \
             "${HOME}/.zshrc.d" \
             "${HOME}/.config/fish/completions" \
             "${HOME}/.config/fish/conf.d" \
             "${HOME}/.config/fish/functions"

    print_info "Setting up shell aliases..."
    echo '[ -f "/usr/share/soltros/bling/aliases.sh" ]; bass source /usr/share/soltros/bling/aliases.sh' | tee "${HOME}/.config/fish/conf.d/soltros-aliases.fish" >/dev/null
    echo '[ -f "/usr/share/soltros/bling/aliases.sh" ] && . "/usr/share/soltros/bling/aliases.sh"' | tee "${HOME}/.bashrc.d/soltros-aliases.bashrc" "${HOME}/.zshrc.d/soltros-aliases.zshrc" >/dev/null

    print_info "Setting up shell defaults..."
    echo '[ -f "/usr/share/soltros/bling/defaults.fish" ]; source /usr/share/soltros/bling/defaults.fish' | tee "${HOME}/.config/fish/conf.d/soltros-defaults.fish" >/dev/null
    echo '[ -f "/usr/share/soltros/bling/defaults.sh" ] && . "/usr/share/soltros/bling/defaults.sh"' | tee "${HOME}/.bashrc.d/soltros-defaults.bashrc" "${HOME}/.zshrc.d/soltros-defaults.zshrc" >/dev/null

    print_info "Downloading verified Fish plugins..."
    for asset in bass_python bass_fish grc_fish; do
        asset_url="$(jq -er --arg key "${asset}_url" '.shell_assets[$key]' "${SOURCE_LOCK}")"
        asset_sha256="$(jq -er --arg key "${asset}_sha256" '.shell_assets[$key]' "${SOURCE_LOCK}")"
        case "${asset}" in
            bass_python) asset_target="${HOME}/.config/fish/functions/__bass.py" ;;
            bass_fish) asset_target="${HOME}/.config/fish/functions/bass.fish" ;;
            grc_fish) asset_target="${HOME}/.config/fish/conf.d/grc.fish" ;;
        esac
        download_verified "${asset_url}" "${asset_sha256}" "${asset_target}"
    done

    print_info "Setting up Fish tools..."
    printf '%s\n' "[ -f \"\${HOME}/.cargo/env.fish\" ] && source \"\${HOME}/.cargo/env.fish\"" \
        > "${HOME}/.config/fish/conf.d/cargo-env.fish"

    for tool in starship atuin zoxide thefuck direnv; do
        if command -v "$tool" >/dev/null; then
            case "$tool" in
            atuin)
                "$tool" init fish --disable-up-arrow > "${HOME}/.config/fish/conf.d/${tool}.fish"
                ;;
            starship | zoxide)
                $tool init fish > "${HOME}/.config/fish/conf.d/${tool}.fish"
                ;;
            thefuck)
                $tool --alias > "${HOME}/.config/fish/functions/${tool}.fish"
                ;;
            direnv)
                $tool hook fish > "${HOME}/.config/fish/conf.d/${tool}.fish"
                ;;
            esac
        fi
    done

    print_info "Configuring rc file sourcing..."
    for shell in bash zsh; do
        rc_file="${HOME}/.${shell}rc"
        rc_dir=".${shell}rc.d"

        # Check if the snippet already exists
        if [ -f "$rc_file" ] && grep -q "${rc_dir}/\*" "$rc_file"; then
            print_info "RC sourcing already configured for $shell"
        else
            # Add the snippet using printf to avoid parsing issues
            {
                printf '\n%s\n' "# User-specific aliases and functions"
                printf '%s\n' "if [ -d ~/${rc_dir} ]; then"
                printf '%s\n' "  for rc in ~/${rc_dir}/*; do"
                printf '%s\n' "    if [ -f \"\$rc\" ]; then"
                printf '%s\n' "      . \"\$rc\""
                printf '%s\n' "    fi"
                printf '%s\n' "  done"
                printf '%s\n' "fi"
                printf '%s\n' "unset rc"
            } >> "$rc_file"
            print_info "Added RC sourcing for $shell"
        fi
    done

    print_success "Terminal setup complete"
}

setup_distrobox() {
    print_header "Setting up distrobox containers for development"
    
    if ! command -v distrobox &> /dev/null; then
        print_error "Distrobox is not installed"
        exit 1
    fi
    
    # Ubuntu container for general development
    if ! distrobox list | grep -q "ubuntu-dev"; then
        print_info "Creating Ubuntu development container..."
        distrobox create --name ubuntu-dev --image ubuntu:latest
        distrobox enter ubuntu-dev -- sudo apt update && sudo apt install -y build-essential git curl wget
    else
        print_info "Ubuntu development container already exists"
    fi
    
    # Arch container for AUR packages
    if ! distrobox list | grep -q "arch-dev"; then
        print_info "Creating Arch development container..."
        distrobox create --name arch-dev --image archlinux:latest
        distrobox enter arch-dev -- sudo pacman -Syu --noconfirm base-devel git
    else
        print_info "Arch development container already exists"
    fi
    
    print_success "Distrobox setup complete!"
}

# ───────────────────────────────────────────────
# CONFIGURE FUNCTIONS
# ───────────────────────────────────────────────

soltros_enable_amdgpu_oc() {
    print_header "Enabling AMD GPU overclocking support"
    
    if ! command -v rpm-ostree &> /dev/null; then
        print_error "rpm-ostree is not available"
        exit 1
    fi
    
    print_info "Enabling AMD GPU overclocking..."
    
    if ! rpm-ostree kargs | grep -q "amdgpu.ppfeaturemask="; then
        sudo rpm-ostree kargs --append "amdgpu.ppfeaturemask=0xFFF7FFFF"
        print_success "Kernel argument set. Reboot required to take effect."
    else
        print_warning "Overclocking already enabled"
    fi
}

toggle_session() {
    print_header "Session Toggle Information"
    
    current_session="${XDG_SESSION_TYPE:-unknown}"
    print_info "Current session: $current_session"
    
    if [ "$current_session" = "wayland" ]; then
        print_info "To switch to X11:"
        echo "1. Log out of your current session"
        echo "2. On the login screen, click the gear icon"
        echo "3. Select the X11 session option"
        echo "4. Log back in"
    else
        print_info "To switch to Wayland:"
        echo "1. Log out of your current session"
        echo "2. On the login screen, click the gear icon"
        echo "3. Select the Wayland session option"
        echo "4. Log back in"
    fi
}

# ───────────────────────────────────────────────
# UNIVERSAL BLUE FUNCTIONS
# ───────────────────────────────────────────────

ublue_clean() {
    print_header "Cleaning up the system"
    
    print_info "Cleaning rpm-ostree..."
    sudo rpm-ostree cleanup -p || true
    
    print_info "Cleaning Flatpak cache..."
    flatpak uninstall --unused -y || true
    
    print_info "Cleaning system cache..."
    sudo journalctl --vacuum-time=7d || true
    
    print_success "System cleanup complete"
}

ublue_distrobox() {
    print_header "Managing distrobox containers"
    
    if ! command -v distrobox &> /dev/null; then
        print_error "Distrobox is not installed"
        exit 1
    fi
    
    print_info "Available distrobox containers:"
    distrobox list
}

ublue_toolbox() {
    print_header "Managing toolbox containers"
    
    if ! command -v toolbox &> /dev/null; then
        print_error "Toolbox is not installed"
        exit 1
    fi
    
    print_info "Available toolbox containers:"
    toolbox list
}

# ───────────────────────────────────────────────
# MAIN SCRIPT LOGIC
# ───────────────────────────────────────────────

main() {
    case "${1:-help}" in
        "install")
            soltros_install
            ;;
        "install-flatpaks")
            soltros_install_flatpaks
            ;;
        "install-dev-tools")
            install_dev_tools
            ;;
        "install-gaming")
            install_gaming
            ;;
        "install-multimedia")
            install_multimedia
            ;;
        "install-homebrew")
            install_homebrew
            ;;
        "install-nix")
            install_nix
            ;;
        "setup-nixmanager")
            setup_nixmanager
            ;;
        "install-oh-my-zsh")
            install_oh_my_zsh
            ;;
        "change-to-zsh")
            change_to_zsh
            ;;
        "setup-git")
            soltros_setup_git
            ;;
        "setup-cli")
            soltros_setup_cli
            ;;
        "setup-distrobox")
            setup_distrobox
            ;;
        "enable-amdgpu-oc")
            soltros_enable_amdgpu_oc
            ;;
        "toggle-session")
            toggle_session
            ;;
        "status"|"update"|"rollback"|"doctor"|"report")
            exec /usr/libexec/soltros/system.sh "$1"
            ;;
        "clean")
            ublue_clean
            ;;
        "distrobox")
            ublue_distrobox
            ;;
        "toolbox")
            ublue_toolbox
            ;;
        "list")
            list_commands
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run 'soltros help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
