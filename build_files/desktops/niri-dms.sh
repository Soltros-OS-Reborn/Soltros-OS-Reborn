#!/usr/bin/bash

set -euo pipefail

/ctx/desktops/niri-common.sh

echo "=== Installing Dank Material Shell ==="
dnf5 -y copr enable avengemedia/dms
dnf5 -y install adw-gtk3-theme dms dms-greeter danksearch dgop kitty quickshell

test -f /usr/lib/systemd/user/dms.service
systemctl --global enable dms.service
systemctl --global is-enabled --quiet dms.service
rpm -q adw-gtk3-theme dms dms-greeter danksearch dgop kitty quickshell
test -x /usr/bin/pywalfox
test -x /usr/bin/ghostty
echo "=== Niri with Dank Material Shell installed ==="
