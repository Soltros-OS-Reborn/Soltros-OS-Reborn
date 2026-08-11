#!/usr/bin/bash
# SoltrOS: Container Signing Setup Script
# Author: Derrik
# Description: Configures sigstore signing trust for ghcr.io/soltros-os-reborn containers

set ${SET_X:+-x} -eou pipefail

# Variables
NAMESPACE="soltros-os-reborn"
PUBKEY="/etc/pki/containers/soltros.pub"
POLICY="/etc/containers/policy.json"
REGISTRY="ghcr.io/${NAMESPACE}"
MANIFEST="/ctx/desktop-variants.json"

log() {
  echo "=== $* ==="
}

log "Preparing directories"
mkdir -p /etc/containers
mkdir -p /etc/pki/containers
mkdir -p /etc/containers/registries.d/

log "Setting up secure policy.json"
jq --arg registry "${REGISTRY}" --arg key_path "${PUBKEY}" '
  reduce .[].image_name as $image (
    {};
    .[$registry + "/" + $image] = [{
      type: "sigstoreSigned",
      keyPath: $key_path,
      signedIdentity: {type: "matchRepository"}
    }]
  ) |
  {
    default: [{type: "reject"}],
    transports: {
      docker: .,
      "docker-daemon": {"": [{type: "insecureAcceptAnything"}]}
    }
  }
' "${MANIFEST}" > "${POLICY}"

log "Installing cosign public key"
if [ -f /ctx/soltros.pub ]; then
    # Legacy path for backward compatibility
    cp /ctx/soltros.pub "$PUBKEY"
else
    # Preferred path - key should be copied via Dockerfile
    if [ ! -f "$PUBKEY" ]; then
        echo "ERROR: Public key not found at /ctx/soltros.pub or $PUBKEY" >&2
        exit 1
    fi
fi

log "Setting correct permissions"
chmod 644 "$PUBKEY"
chmod 644 "$POLICY"

log "Creating registry policy YAML"
{
    echo 'docker:'
    while IFS= read -r image_name; do
        printf '  %s/%s:\n' "${REGISTRY}" "${image_name}"
        echo '    use-sigstore-attachments: true'
    done < <(jq -r '.[].image_name' "${MANIFEST}")
} > "/etc/containers/registries.d/${NAMESPACE}.yaml"

log "Verifying policy configuration"
# Basic syntax check
jq empty "$POLICY"

log "Signing policy setup complete for repositories in $REGISTRY"
