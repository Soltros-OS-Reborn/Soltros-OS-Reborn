#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/soltros-installer-config-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
generated="${test_root}/config.toml"
workflow="${repo_root}/.github/workflows/build.yml"
live_installer="${repo_root}/resources/live-install.sh"
liveiso_builder="${repo_root}/disk_config/build-live-iso.sh"

IMAGE_REGISTRY=registry.example.test/soltros IMAGE_TAG=test-tag \
  "${repo_root}/disk_config/generate-iso-config.sh" "${generated}"

for variant in kde gnome niri-dms niri-noctalia; do
  image_name="$(jq -er --arg variant "${variant}" \
    '.[] | select(.id == $variant) | .image_name' \
    "${repo_root}/variants/desktop-variants.json")"
  image_ref="registry.example.test/soltros/${image_name}:test-tag"

  grep -Fq "${image_ref}" "${generated}" || {
    printf 'installer config is missing image reference: %s\n' "${image_ref}" >&2
    exit 1
  }
done

grep -Fq 'soltros.variant=*' "${generated}"
grep -Fq '%include /tmp/soltros-source.ks' "${generated}"
grep -Fq 'org.fedoraproject.Anaconda.Modules.Users' "${generated}"

if grep -Fq '@@IMAGE_' "${generated}"; then
  printf 'installer config contains unresolved image placeholders\n' >&2
  exit 1
fi

if grep -Fq 'soltros-os-reborn/soltros-os-reborn' "${generated}"; then
  printf 'installer config contains the retired fixed image reference\n' >&2
  exit 1
fi

grep -Fq 'disk_config/build-live-iso.sh artifacts' "${workflow}"
grep -Fq 'artifacts/*.iso' "${workflow}"
grep -Fq 'artifacts/*.sha256' "${workflow}"
grep -Fq 'bootc install to-disk' "${live_installer}"
grep -Fq 'desktop-variants.json' "${live_installer}"
grep -Fq "podman save \"\${carrier_image}\" | sudo podman load" \
  "${liveiso_builder}"
grep -Fq "output_dir=\"\$(cd -- \"\${output_dir}\" && pwd)\"" \
  "${liveiso_builder}"
grep -Fq -- '--rootfs=btrfs' "${liveiso_builder}"
grep -Fq -- '--use-librepo=False' "${liveiso_builder}"
grep -Fq 'BIB_DISABLED_REPOS' "${liveiso_builder}"
grep -Fq 'buildah from' "${liveiso_builder}"
grep -Fq "grep -lFx \"[\$1]\" /etc/yum.repos.d/*.repo" \
  "${liveiso_builder}"
grep -Fq "mv \"\${repository_file}\" /etc/soltros-disabled-repos/" \
  "${liveiso_builder}"
grep -Fq "\"\${bib_source_image}\"" "${liveiso_builder}"
grep -Fq "podman image rm \"\${temporary_carrier_image}\"" \
  "${liveiso_builder}"

if grep -Eq -- '--(image|target|add-file)([[:space:]]|$)' "${live_installer}"; then
  printf 'live installer contains obsolete bootc install arguments\n' >&2
  exit 1
fi

printf 'PASS: LiveISO config offers four manifest-backed desktop choices\n'
