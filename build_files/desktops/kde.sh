#!/usr/bin/bash

set -euo pipefail

log() {
  echo "=== $* ==="
}

log "Installing KDE Plasma"
dnf5 -y group install "kde-desktop" "kde-apps" "kde-media"
dnf5 -y install plasma-login-manager python3-dbus python3-file-magic python3-gobject \
  python3-numpy python3-pillow xdg-desktop-portal-kde

systemctl disable gdm.service greetd.service sddm.service 2>/dev/null || true
systemctl enable plasmalogin.service
systemctl set-default graphical.target
systemctl is-enabled --quiet plasmalogin.service

rpm -q plasma-desktop plasma-login-manager python3-dbus python3-file-magic \
  python3-gobject python3-numpy python3-pillow xdg-desktop-portal-kde
test -x /usr/bin/kde-material-you-colors
log "KDE Plasma desktop variant installed"
