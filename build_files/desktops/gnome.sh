#!/usr/bin/bash

set -euo pipefail

log() {
  echo "=== $* ==="
}

log "Installing GNOME"
dnf5 -y group install "gnome-desktop"
dnf5 -y install gdm gnome-boxes gnome-tweaks xdg-desktop-portal-gnome

systemctl disable plasmalogin.service greetd.service sddm.service 2>/dev/null || true
systemctl enable gdm.service
systemctl set-default graphical.target
systemctl is-enabled --quiet gdm.service

rpm -q gnome-shell gdm xdg-desktop-portal-gnome
log "GNOME desktop variant installed"
