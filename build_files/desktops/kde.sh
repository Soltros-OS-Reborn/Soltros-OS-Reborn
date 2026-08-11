#!/usr/bin/bash

set -euo pipefail

log() {
  echo "=== $* ==="
}

log "Installing KDE Plasma"
dnf5 -y group install "kde-desktop" "kde-apps" "kde-media"
dnf5 -y install plasma-login-manager xdg-desktop-portal-kde

systemctl disable gdm.service greetd.service sddm.service 2>/dev/null || true
systemctl enable plasmalogin.service
systemctl set-default graphical.target

rpm -q plasma-desktop plasma-login-manager xdg-desktop-portal-kde
log "KDE Plasma desktop variant installed"
