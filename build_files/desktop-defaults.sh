#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Enable podman socket"
systemctl enable podman.socket
systemctl is-enabled --quiet podman.socket

log "Enable thermal management services"
systemctl enable thermald
systemctl enable mbpfan.service
systemctl is-enabled --quiet thermald.service
systemctl is-enabled --quiet mbpfan.service

log "Enable user-default migration"
systemctl --global enable soltros-user-defaults.service
systemctl --global is-enabled --quiet soltros-user-defaults.service

log "Validate native first-login setup"
rpm -q gtk4 libadwaita python3-gobject
test -x /usr/bin/soltros-welcome
test -f /etc/xdg/autostart/org.soltros.Welcome.desktop
test -f /usr/share/applications/org.soltros.Welcome.desktop
