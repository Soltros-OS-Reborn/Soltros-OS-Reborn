#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Creating /nix and downloading the pinned Determinate Nix installer."

source_lock=/ctx/sources.lock.json
version="$(jq -er '.nix_installer.version' "${source_lock}")"
expected_sha256="$(jq -er '.nix_installer.script_sha256' "${source_lock}")"
installer=/nix/determinate-nix-installer.sh

mkdir -p /nix
curl --proto '=https' --tlsv1.2 --fail --location --retry 3 \
  "https://github.com/DeterminateSystems/nix-installer/releases/download/v${version}/nix-installer.sh" \
  --output "${installer}"
printf '%s  %s\n' "${expected_sha256}" "${installer}" | sha256sum --check --status
chmod 0755 "${installer}"
