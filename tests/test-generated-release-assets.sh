#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
generator="${repo_root}/tools/generate-release-assets.sh"

"${generator}" --check
jq -e '.variant_count == 4 and (.variants | length == 4)' \
  "${repo_root}/release/generated/release-metadata.json" >/dev/null
jq -e '.desktop | length == 4' \
  "${repo_root}/release/generated/desktop-matrix.json" >/dev/null
jq -e '.offline_required == true and .online_update_default == false and .variant_count == 4' \
  "${repo_root}/release/generated/installer-profile.json" >/dev/null
jq -e '(.manual_transitions | length == 3) and .automatic_channel == "dev"' \
  "${repo_root}/release/generated/channel-policy.json" >/dev/null
for image_name in $(jq -r '.[].image_name' "${repo_root}/variants/desktop-variants.json"); do
  grep -Fq "ghcr.io/soltros-os-reborn/${image_name}:" \
    "${repo_root}/release/generated/registries.yaml"
done

printf 'PASS: release assets are generated from the release and variant manifests\n'
