#!/usr/bin/env bash

set -euo pipefail

variant="${DESKTOP_VARIANT:?DESKTOP_VARIANT is required}"
target="/usr/share/soltros/defaults/${variant}"

mkdir -p "${target}"
if [[ -d /etc/skel/.config/niri ]]; then
  mkdir -p "${target}/.config"
  cp -a /etc/skel/.config/niri "${target}/.config/"
fi
