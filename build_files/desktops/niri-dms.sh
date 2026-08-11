#!/usr/bin/bash

set -euo pipefail

/ctx/desktops/niri-common.sh

echo "=== Installing Dank Material Shell ==="
dnf5 -y copr enable avengemedia/dms
dnf5 -y install dms dms-greeter danksearch dgop quickshell

test -f /usr/lib/systemd/user/dms.service
systemctl --global enable dms.service
rpm -q dms dms-greeter danksearch dgop quickshell
echo "=== Niri with Dank Material Shell installed ==="
