#!/usr/bin/bash

set -euo pipefail

/ctx/desktops/niri-common.sh

echo "=== Installing Noctalia ==="
dnf5 -y install noctalia
rpm -q noctalia
command -v noctalia >/dev/null
echo "=== Niri with Noctalia installed ==="
