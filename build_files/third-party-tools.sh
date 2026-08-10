#!/usr/bin/bash

set ${SET_X:+-x} -euo pipefail

log() {
  echo "=== $* ==="
}

DESTDIR="${1:-/out}"
STARSHIP_VERSION="1.26.0"
MBPFAN_VERSION="2.4.0"

case "$(uname -m)" in
  x86_64)
    STARSHIP_TARGET="x86_64-unknown-linux-gnu"
    STARSHIP_SHA256="321f0dd7af8340a5f2e6a8fec6538a04f617486f9ec70d878f91c09cd8deef22"
    ;;
  aarch64)
    STARSHIP_TARGET="aarch64-unknown-linux-musl"
    STARSHIP_SHA256="dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b"
    ;;
  *)
    echo "Unsupported architecture for the pinned Starship release: $(uname -m)" >&2
    exit 1
    ;;
esac

MBPFAN_SHA256="e1cdcffaba52be215ae40a8568949190866d500d6ae2a1e96b71ab5372f3580b"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

download_verified() {
  local url="$1"
  local expected_sha256="$2"
  local output="$3"

  curl --fail --location --retry 3 --retry-delay 5 --output "$output" "$url"
  printf '%s  %s\n' "$expected_sha256" "$output" | sha256sum --check --status
}

log "Installing Starship ${STARSHIP_VERSION}"
STARSHIP_ARCHIVE="$WORKDIR/starship.tar.gz"
download_verified \
  "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-${STARSHIP_TARGET}.tar.gz" \
  "$STARSHIP_SHA256" \
  "$STARSHIP_ARCHIVE"
mkdir -p "$WORKDIR/starship"
tar -xzf "$STARSHIP_ARCHIVE" -C "$WORKDIR/starship"
install -D -m 0755 "$WORKDIR/starship/starship" "$DESTDIR/usr/bin/starship"

log "Building mbpfan ${MBPFAN_VERSION}"
MBPFAN_ARCHIVE="$WORKDIR/mbpfan.tar.gz"
download_verified \
  "https://github.com/linux-on-mac/mbpfan/archive/refs/tags/v${MBPFAN_VERSION}.tar.gz" \
  "$MBPFAN_SHA256" \
  "$MBPFAN_ARCHIVE"
tar -xzf "$MBPFAN_ARCHIVE" -C "$WORKDIR"
MBPFAN_SOURCE="$WORKDIR/mbpfan-${MBPFAN_VERSION}"
make -C "$MBPFAN_SOURCE"
install -D -m 0755 "$MBPFAN_SOURCE/bin/mbpfan" "$DESTDIR/usr/bin/mbpfan"
install -D -m 0644 "$MBPFAN_SOURCE/mbpfan.service" "$DESTDIR/usr/lib/systemd/system/mbpfan.service"
install -D -m 0644 "$MBPFAN_SOURCE/mbpfan.depend.conf" "$DESTDIR/usr/lib/modules-load.d/mbpfan.conf"
install -D -m 0644 "$MBPFAN_SOURCE/mbpfan.8.gz" "$DESTDIR/usr/share/man/man8/mbpfan.8.gz"
install -D -m 0644 "$MBPFAN_SOURCE/COPYING" "$DESTDIR/usr/share/licenses/mbpfan/COPYING"

log "Third-party tools installed"
STARSHIP_CACHE="$WORKDIR/starship-cache" "$DESTDIR/usr/bin/starship" --version
"$DESTDIR/usr/bin/mbpfan" -h
