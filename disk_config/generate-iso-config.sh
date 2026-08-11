#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${repo_root}/variants/desktop-variants.json"
template="${repo_root}/disk_config/iso.toml"
output="${1:?output config path is required}"
registry="${IMAGE_REGISTRY:-ghcr.io/soltros-os-reborn}"
tag="${IMAGE_TAG:-latest}"

registry="${registry,,}"
registry="${registry%/}"

declare -A image_names=()
while IFS=$'\t' read -r variant image_name; do
  image_names["${variant}"]="${image_name}"
done < <(jq -r '.[] | [.id, .image_name] | @tsv' "${manifest}")

content="$(<"${template}")"
for variant in kde gnome niri-dms niri-noctalia; do
  image_name="${image_names[${variant}]:-}"
  if [[ -z "${image_name}" ]]; then
    echo "Desktop variant is missing from the manifest: ${variant}" >&2
    exit 1
  fi

  placeholder="@@IMAGE_${variant^^}@@"
  placeholder="${placeholder//-/_}"
  image_ref="${registry}/${image_name}:${tag}"
  content="${content//${placeholder}/${image_ref}}"
done

if grep -Fq '@@IMAGE_' <<<"${content}"; then
  echo "Installer template contains unresolved image placeholders" >&2
  exit 1
fi

mkdir -p "$(dirname -- "${output}")"
printf '%s\n' "${content}" > "${output}"
