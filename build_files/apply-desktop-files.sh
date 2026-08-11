#!/usr/bin/bash

set -euo pipefail

desktop_files_root="${1:?desktop file root is required}"
target_root="${2:-/}"
desktop_variant="${DESKTOP_VARIANT:-kde}"

[[ -d "${desktop_files_root}" ]] || {
  echo "Desktop file root does not exist: ${desktop_files_root}" >&2
  exit 1
}
mkdir -p "${target_root}"

case "${desktop_variant}" in
  kde|gnome|niri-dms|niri-noctalia)
    ;;
  *)
    echo "Unsupported desktop variant: ${desktop_variant}" >&2
    exit 1
    ;;
esac

apply_layer() {
  local layer="$1"

  if [[ -d "${desktop_files_root}/${layer}" ]]; then
    cp -a "${desktop_files_root}/${layer}/." "${target_root}/"
  fi
}

if [[ "${desktop_variant}" == niri-* ]]; then
  apply_layer niri-common
fi
apply_layer "${desktop_variant}"
