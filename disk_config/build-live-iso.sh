#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-${repo_root}/output/liveiso}"
registry="${IMAGE_REGISTRY:-ghcr.io/soltros-os-reborn}"
tag="${IMAGE_TAG:-latest}"
bib_image="${BIB_IMAGE:-quay.io/centos-bootc/bootc-image-builder@sha256:afeffdb5a7ab6bb9d0593b5765412c4d821a9492dbaf26bb5a494e27181d2019}"
disabled_repos="${BIB_DISABLED_REPOS:-updates}"

registry="${registry,,}"
registry="${registry%/}"
carrier_name="$(jq -er '.[] | select(.id == "kde") | .image_name' \
  "${repo_root}/variants/desktop-variants.json")"
carrier_image="${INSTALLER_SOURCE_IMAGE:-${registry}/${carrier_name}:${tag}}"
work_dir="$(mktemp -d /tmp/soltros-liveiso-XXXXXX)"
temporary_carrier_image=""
carrier_container=""

cleanup() {
  local status=$?

  trap - EXIT
  if [[ -n "${carrier_container}" ]]; then
    sudo buildah rm "${carrier_container}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${temporary_carrier_image}" ]]; then
    sudo podman image rm "${temporary_carrier_image}" >/dev/null 2>&1 || true
  fi
  rm -rf "${work_dir}"
  exit "${status}"
}

trap cleanup EXIT

mkdir -p "${output_dir}"
output_dir="$(cd -- "${output_dir}" && pwd)"
rm -rf "${output_dir}/bootiso"

IMAGE_REGISTRY="${registry}" IMAGE_TAG="${tag}" \
  "${repo_root}/disk_config/generate-iso-config.sh" "${work_dir}/config.toml"

if [[ "${carrier_image}" == localhost/* ]]; then
  if ! sudo podman image exists "${carrier_image}"; then
    if ! podman image exists "${carrier_image}"; then
      echo "Local installer source image does not exist: ${carrier_image}" >&2
      exit 1
    fi
    podman save "${carrier_image}" | sudo podman load
  fi
else
  sudo podman pull "${carrier_image}"
fi

bib_source_image="${carrier_image}"
if [[ -n "${disabled_repos}" ]]; then
  temporary_carrier_image="localhost/soltros-liveiso-carrier:${tag}-$$"
  carrier_container="soltros-liveiso-carrier-$$"
  sudo buildah from --name "${carrier_container}" "${carrier_image}" >/dev/null

  read -r -a disabled_repo_list <<< "${disabled_repos//,/ }"
  for repository in "${disabled_repo_list[@]}"; do
    if [[ ! "${repository}" =~ ^[[:alnum:]_.:-]+$ ]]; then
      echo "Invalid repository ID in BIB_DISABLED_REPOS: ${repository}" >&2
      exit 1
    fi

    mapfile -t repository_files < <(
      sudo buildah run "${carrier_container}" -- bash -lc \
        'grep -lFx "[$1]" /etc/yum.repos.d/*.repo' _ "${repository}"
    )
    if (( ${#repository_files[@]} == 0 )); then
      echo "Repository is not defined in the carrier image: ${repository}" >&2
      exit 1
    fi

    sudo buildah run "${carrier_container}" -- \
      mkdir -p /etc/soltros-disabled-repos
    for repository_file in "${repository_files[@]}"; do
      sudo buildah run "${carrier_container}" -- \
        mv "${repository_file}" /etc/soltros-disabled-repos/
    done
  done

  sudo buildah commit --rm "${carrier_container}" \
    "${temporary_carrier_image}" >/dev/null
  carrier_container=""
  bib_source_image="${temporary_carrier_image}"
fi

sudo podman run \
  --rm \
  --privileged \
  --net host \
  --security-opt label=type:unconfined_t \
  -v "${work_dir}/config.toml:/config.toml:ro" \
  -v "${output_dir}:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  "${bib_image}" \
  --type anaconda-iso \
  --use-librepo=False \
  --rootfs=btrfs \
  "${bib_source_image}"

iso_path="${output_dir}/SoltrOS-${tag}-live-installer-x86_64.iso"
sudo mv "${output_dir}/bootiso/install.iso" "${iso_path}"
sudo rm -rf "${output_dir}/bootiso"
sudo chown "$(id -u):$(id -g)" "${iso_path}"
sha256sum "${iso_path}" > "${iso_path}.sha256"

printf 'ISO=%s\n' "${iso_path}"
printf 'CHECKSUM=%s\n' "${iso_path}.sha256"
