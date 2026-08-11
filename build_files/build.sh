#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

# Define log function first (before any usage)
log() {
  echo "== $* =="
}

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

function echo_group() {
    local WHAT
    WHAT="$(
        basename "$1" .sh |
            tr "-" " " |
            tr "_" " "
    )"
    echo "::group:: == ${WHAT^^} =="
    "$@"
    echo "::endgroup::"
}

log "Starting SoltrOS build process"

# Base image for reference
BASE_IMAGE="${BASE_IMAGE:-ghcr.io/ublue-os/base-main}"
DESKTOP_VARIANT="${DESKTOP_VARIANT:-kde}"
BUILD_PHASE="${BUILD_PHASE:-all}"
readonly BASE_IMAGE DESKTOP_VARIANT BUILD_PHASE
export BASE_IMAGE DESKTOP_VARIANT BUILD_PHASE

case "${BUILD_PHASE}" in
  all|common|desktop)
    ;;
  *)
    echo "Unsupported build phase: ${BUILD_PHASE}" >&2
    exit 1
    ;;
esac

log "Building for base image: $BASE_IMAGE"

run_common_phase() {
  log "Enable container signing"
  echo_group /ctx/signing.sh

  log "Setup /nix and download Determinite Systems Nix installer"
  echo_group /ctx/nix-package-manager.sh

  log "Install Waterfox browser BIN"
  echo_group /ctx/waterfox-installer.sh

  log "Install shared desktop packages"
  echo_group /ctx/desktop-packages.sh

  log "Enable gaming enhancements"
  echo_group /ctx/gaming.sh

  log "Apply system overrides"
  echo_group /ctx/overrides.sh
}

run_desktop_phase() {
  case "${DESKTOP_VARIANT}" in
    kde|gnome|niri-dms|niri-noctalia)
      ;;
    *)
      echo "Unsupported desktop variant: ${DESKTOP_VARIANT}" >&2
      exit 1
      ;;
  esac

  log "Building desktop variant: $DESKTOP_VARIANT"
  log "Install ${DESKTOP_VARIANT} desktop variant"
  echo_group "/ctx/desktops/${DESKTOP_VARIANT}.sh"

  install -D -m 0644 /dev/stdin /usr/lib/soltros/desktop-variant <<EOF
${DESKTOP_VARIANT}
EOF

  log "Apply ${DESKTOP_VARIANT} desktop files"
  echo_group /ctx/apply-desktop-files.sh /ctx/desktop-files
  if command -v dconf >/dev/null 2>&1; then
    dconf update
  fi

  log "Setup desktop defaults"
  echo_group /ctx/desktop-defaults.sh

  log "Build InitramFS"
  echo_group /ctx/build-initramfs.sh

  log "Post build cleanup"
  echo_group /ctx/cleanup.sh
}

case "${BUILD_PHASE}" in
  common)
    run_common_phase
    ;;
  desktop)
    run_desktop_phase
    ;;
  all)
    run_common_phase
    run_desktop_phase
    ;;
esac

log "SoltrOS build process completed successfully"
