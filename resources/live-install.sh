#!/usr/bin/env bash

set -euo pipefail

manifest="${SOLTROS_VARIANT_MANIFEST:-/usr/share/soltros/desktop-variants.json}"
registry="${IMAGE_REGISTRY:-ghcr.io/soltros-os-reborn}"
tag="${IMAGE_TAG:-latest}"

registry="${registry,,}"
registry="${registry%/}"

if [[ ! -r "${manifest}" ]]; then
    echo "Desktop variant manifest is not readable: ${manifest}" >&2
    exit 1
fi

mapfile -t variants < <(jq -r '.[] | [.id, .display_name, .image_name] | @tsv' "${manifest}")
if [[ "${#variants[@]}" -ne 4 ]]; then
    echo "Expected four desktop variants in ${manifest}" >&2
    exit 1
fi

printf '%s\n' 'SoltrOS Reborn desktop selection' ''
for index in "${!variants[@]}"; do
    IFS=$'\t' read -r variant display_name image_name <<<"${variants[${index}]}"
    printf '  %d) %s (%s)\n' "$((index + 1))" "${display_name}" "${variant}"
done

while :; do
    read -rp 'Select a desktop [1-4]: ' selection
    if [[ "${selection}" =~ ^[1-4]$ ]]; then
        break
    fi
    echo 'Enter a number from 1 to 4.'
done

IFS=$'\t' read -r variant display_name image_name <<<"${variants[$((selection - 1))]}"
image="${registry}/${image_name}:${tag}"

read -rp 'Enter the target disk (for example, /dev/sda): ' target
if [[ ! -b "${target}" ]]; then
    echo "Target is not a block device: ${target}" >&2
    exit 1
fi

printf 'Desktop: %s\nImage: %s\nTarget: %s\n' "${display_name}" "${image}" "${target}"
printf 'All data on %s will be erased.\n' "${target}"
read -rp 'Type INSTALL to continue: ' confirmation
if [[ "${confirmation}" != INSTALL ]]; then
    echo 'Installation cancelled.'
    exit 1
fi

sudo bootc install to-disk \
    --wipe \
    --source-imgref "docker://${image}" \
    --target-imgref "${image}" \
    "${target}"

printf 'Installed the %s variant to %s.\n' "${variant}" "${target}"
