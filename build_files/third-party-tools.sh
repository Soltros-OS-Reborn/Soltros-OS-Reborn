#!/usr/bin/bash

set ${SET_X:+-x} -euo pipefail

log() {
  echo "=== $* ==="
}

DESTDIR="${1:-/out}"
SOURCE_LOCK="${2:-/usr/share/soltros/sources.lock.json}"

if [[ ! -r "${SOURCE_LOCK}" ]]; then
  echo "Source lock is not readable: ${SOURCE_LOCK}" >&2
  exit 1
fi

STARSHIP_VERSION="$(jq -er '.starship.version' "${SOURCE_LOCK}")"
MBPFAN_VERSION="$(jq -er '.mbpfan.version' "${SOURCE_LOCK}")"

case "$(uname -m)" in
  x86_64)
    STARSHIP_TARGET="x86_64-unknown-linux-gnu"
    STARSHIP_SHA256="$(jq -er '.starship.x86_64_unknown_linux_gnu_sha256' "${SOURCE_LOCK}")"
    ;;
  aarch64)
    STARSHIP_TARGET="aarch64-unknown-linux-musl"
    STARSHIP_SHA256="$(jq -er '.starship.aarch64_unknown_linux_musl_sha256' "${SOURCE_LOCK}")"
    ;;
  *)
    echo "Unsupported architecture for the pinned Starship release: $(uname -m)" >&2
    exit 1
    ;;
esac

MBPFAN_SHA256="$(jq -er '.mbpfan.source_sha256' "${SOURCE_LOCK}")"
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
