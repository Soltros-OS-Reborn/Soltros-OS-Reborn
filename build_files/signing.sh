#!/usr/bin/bash
# SoltrOS: Container Signing Setup Script
# Description: Configures sigstore signing trust for ghcr.io/soltros-os-reborn containers

set ${SET_X:+-x} -eou pipefail

PUBKEY="/usr/share/pki/containers/soltros.pub"
POLICY="/etc/containers/policy.json"
REGISTRY_POLICY="/etc/containers/registries.d/soltros.yaml"

log() {
  echo "=== $* ==="
}

log "Preparing directories"
mkdir -p /etc/containers
mkdir -p /usr/share/pki/containers
mkdir -p /etc/containers/registries.d/

log "Installing generated container trust policy"
install -m 0644 /ctx/policy.json "${POLICY}"

log "Installing cosign public key"
if [ -f /ctx/soltros.pub ]; then
    cp /ctx/soltros.pub "$PUBKEY"
else
    if [ ! -f "$PUBKEY" ]; then
        echo "ERROR: Public key not found at /ctx/soltros.pub or $PUBKEY" >&2
        exit 1
    fi
fi

log "Setting correct permissions"
chmod 644 "$PUBKEY"
chmod 644 "$POLICY"

log "Installing generated registry policy"
install -m 0644 /ctx/registries.yaml "${REGISTRY_POLICY}"

log "Verifying policy configuration"
jq empty "$POLICY"

log "Signing policy setup complete"
