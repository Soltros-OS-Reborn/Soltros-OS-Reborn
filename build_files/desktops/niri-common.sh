#!/usr/bin/bash

set -euo pipefail

log() {
  echo "=== $* ==="
}

log "Installing the shared Niri session"
dnf5 -y copr enable yalter/niri
dnf5 -y copr enable ulysg/xwayland-satellite
dnf5 -y install \
  alacritty \
  fuzzel \
  gnome-keyring \
  greetd \
  nautilus \
  niri \
  wl-clipboard \
  xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk \
  xwayland-satellite

systemctl disable gdm.service plasmalogin.service sddm.service 2>/dev/null || true
systemctl enable greetd.service
systemctl set-default graphical.target
systemctl is-enabled --quiet greetd.service

rpm -q greetd niri xdg-desktop-portal-gnome xwayland-satellite
log "Shared Niri session installed"
