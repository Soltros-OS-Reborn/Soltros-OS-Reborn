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

manifest="${SOLTROS_VARIANT_MANIFEST:-/ctx/desktop-variants.json}"
if [[ ! -r "${manifest}" ]] ||
    ! jq -e --arg id "${desktop_variant}" \
      'any(.[]; .id == $id)' "${manifest}" >/dev/null; then
  echo "Unsupported desktop variant: ${desktop_variant}" >&2
  exit 1
fi

apply_layer() {
  local layer="$1"

  if [[ -d "${desktop_files_root}/${layer}" ]]; then
    cp -a "${desktop_files_root}/${layer}/." "${target_root}/"
  fi
}

apply_layer shared
if [[ "${desktop_variant}" == niri-* ]]; then
  apply_layer niri-common
fi
apply_layer "${desktop_variant}"
