#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${repo_root}/variants/desktop-variants.json"
release_manifest="${repo_root}/release/release.json"
template="${repo_root}/disk_config/iso.toml"
output="${1:?output config path is required}"
registry="${IMAGE_REGISTRY:-$(jq -er '.publication.registry' "${release_manifest}")}"
tag="${IMAGE_TAG:-$(jq -er '.channels.development' "${release_manifest}")}"

registry="${registry,,}"
registry="${registry%/}"

content="$(<"${template}")"
while IFS=$'\t' read -r variant image_name; do
  placeholder="@@IMAGE_${variant^^}@@"
  placeholder="${placeholder//-/_}"
  image_ref="${registry}/${image_name}:${tag}"
  content="${content//${placeholder}/${image_ref}}"
done < <(jq -r '.[] | [.id, .image_name] | @tsv' "${manifest}")

if grep -Fq '@@IMAGE_' <<<"${content}"; then
  echo "Installer template contains unresolved image placeholders" >&2
  exit 1
fi

mkdir -p "$(dirname -- "${output}")"
printf '%s\n' "${content}" > "${output}"
