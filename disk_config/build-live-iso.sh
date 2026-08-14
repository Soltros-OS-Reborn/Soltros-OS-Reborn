#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-${repo_root}/output/liveiso}"
registry="${IMAGE_REGISTRY:-localhost/soltros-reborn}"
tag="${IMAGE_TAG:-dev}"
source_lock="${repo_root}/release/sources.lock.json"
live_builder_image="$(jq -er '.live_media_builder.image + "@" + .live_media_builder.digest' "${source_lock}")"
payload_dir="${OFFLINE_PAYLOAD_DIR:-}"
compression="${LIVEISO_COMPRESSION:-xz}"
existing_rootfs="${LIVEISO_ROOTFS_IMAGE:-}"
build_cpus="${LIVEISO_BUILD_CPUS:-4}"
build_memory="${LIVEISO_BUILD_MEMORY:-8g}"
minimum_free_bytes="${LIVEISO_MIN_FREE_BYTES:-}"

case "${compression}" in
  xz|zstd|gzip|lz4) ;;
  *)
    echo "Unsupported LiveISO compression: ${compression}" >&2
    exit 1
    ;;
esac

registry="${registry,,}"
registry="${registry%/}"
carrier_name="$(jq -er '.[] | select(.id == "kde") | .image_name' \
  "${repo_root}/variants/desktop-variants.json")"
carrier_image="${INSTALLER_SOURCE_IMAGE:-${registry}/${carrier_name}:${tag}}"
carrier_container=""
carrier_mount=""
rootfs_mount=""
builder_container=""
builder_image=""
builder_image_temporary="false"
lorax_work_dir=""
fedora_version="$(jq -er '.product.fedora_version' "${repo_root}/release/release.json")"
builder_cache_image="localhost/soltros-live-media-builder:fedora${fedora_version}"

cleanup() {
  local status=$?

  trap - EXIT
  if [[ -n "${rootfs_mount}" ]] && mountpoint -q "${rootfs_mount}"; then
    sudo umount "${rootfs_mount}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${rootfs_mount}" ]]; then
    rmdir "${rootfs_mount}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${carrier_mount}" && -n "${carrier_container}" ]]; then
    sudo buildah unmount "${carrier_container}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${carrier_container}" ]]; then
    sudo buildah rm "${carrier_container}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${builder_container}" ]]; then
    sudo buildah rm "${builder_container}" >/dev/null 2>&1 || true
  fi
  if [[ "${builder_image_temporary}" == "true" && -n "${builder_image}" ]]; then
    sudo podman image rm "${builder_image}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${lorax_work_dir}" && -d "${lorax_work_dir}" ]]; then
    sudo rm -rf "${lorax_work_dir}"
  fi
  exit "${status}"
}

trap cleanup EXIT

label_live_rootfs() {
  local file_contexts
  local label_log
  local required_path

  rootfs_mount="$(mktemp -d /tmp/soltros-live-rootfs-label-XXXXXX)"
  sudo mount -o loop,rw "${rootfs_image}" "${rootfs_mount}"
  file_contexts="${rootfs_mount}/etc/selinux/targeted/contexts/files/file_contexts"
  test -s "${file_contexts}"
  test -x "${rootfs_mount}/usr/sbin/setfiles"
  test -x "${rootfs_mount}/usr/bin/getfattr"
  label_log="${rootfs_mount}/tmp/soltros-liveiso-setfiles.log"

  if ! sudo chroot "${rootfs_mount}" \
      /usr/sbin/setfiles -Fq /etc/selinux/targeted/contexts/files/file_contexts / \
      2>"${label_log}"; then
    sudo tail -n 50 "${label_log}" >&2
    exit 1
  fi
  sudo rm -f "${label_log}"

  for required_path in /etc /usr/lib/systemd/systemd /var; do
    if ! sudo chroot "${rootfs_mount}" \
      /usr/bin/getfattr -n security.selinux "${required_path}" >/dev/null 2>&1; then
      echo "SELinux label was not applied to LiveISO rootfs path: ${required_path}" >&2
      exit 1
    fi
  done

  sudo umount "${rootfs_mount}"
  rmdir "${rootfs_mount}"
  rootfs_mount=""
}

mkdir -p "${output_dir}"
output_dir="$(cd -- "${output_dir}" && pwd)"
if [[ -z "${payload_dir}" ]]; then
  payload_dir="${output_dir}/offline-payload"
fi

available_bytes="$(df --output=avail --block-size=1 "${output_dir}" | tail -n 1 | tr -d ' ')"
if [[ -n "${existing_rootfs}" ]]; then
  existing_rootfs="$(realpath "${existing_rootfs}")"
  test -s "${existing_rootfs}"
  rootfs_allocated_bytes="$(( $(stat --format='%b' "${existing_rootfs}") * 512 ))"
  required_free_bytes="$(( rootfs_allocated_bytes * 2 + 21474836480 ))"
else
  payload_allocated_bytes=0
  if [[ -d "${payload_dir}" ]]; then
    payload_allocated_bytes="$(du -s --block-size=1 "${payload_dir}" | awk '{ print $1 }')"
  fi
  required_free_bytes="$(( payload_allocated_bytes * 3 + 64424509440 ))"
fi
if [[ -n "${minimum_free_bytes}" ]]; then
  required_free_bytes="${minimum_free_bytes}"
fi
if (( available_bytes < required_free_bytes )); then
  printf 'Insufficient free space for LiveISO build: available=%s required=%s output=%s\n' \
    "${available_bytes}" "${required_free_bytes}" "${output_dir}" >&2
  exit 1
fi

while IFS=$'\t' read -r image_name; do
  image_ref="${registry}/${image_name}:${tag}"
  if [[ "${image_ref}" == localhost/* ]]; then
    if ! sudo podman image exists "${image_ref}"; then
      if ! podman image exists "${image_ref}"; then
        echo "Local desktop image does not exist: ${image_ref}" >&2
        exit 1
      fi
      podman save "${image_ref}" | sudo podman load >/dev/null
    fi
  else
    sudo podman pull "${image_ref}" >/dev/null
  fi
done < <(jq -r '.[].image_name' "${repo_root}/variants/desktop-variants.json")

if [[ -n "${existing_rootfs}" ]]; then
  rootfs_image="${existing_rootfs}"
else
  mkdir -p "${payload_dir}"
  if [[ ! -f "${payload_dir}/catalog.json" ]]; then
    sudo env IMAGE_REGISTRY="${registry}" IMAGE_TAG="${tag}" BUILD_ID="${BUILD_ID:-${tag}}" \
      "${repo_root}/disk_config/build-offline-payload.sh" "${payload_dir}"
    sudo chown -R "$(id -u):$(id -g)" "${payload_dir}"
  fi

  carrier_container="soltros-liveiso-carrier-$$"
  sudo buildah from --name "${carrier_container}" "${carrier_image}" >/dev/null
  sudo buildah copy "${carrier_container}" \
    "${repo_root}/resources/live-install.sh" /usr/share/soltros/bin/live-install
  sudo buildah copy "${carrier_container}" \
    "${repo_root}/resources/live" /usr/share/soltros/live
  sudo buildah copy "${carrier_container}" "${payload_dir}" /usr/share/soltros/installer
  sudo buildah run "${carrier_container}" -- chmod 0755 /usr/share/soltros/bin/live-install /usr/share/soltros/live/prepare-root.sh
  sudo buildah run "${carrier_container}" -- /usr/share/soltros/live/prepare-root.sh

  carrier_mount="$(sudo buildah mount "${carrier_container}")"
  rootfs_size="$(sudo du -sx --block-size=1 "${carrier_mount}" | awk '{ print $1 + 4294967296 }')"
  rootfs_image="${output_dir}/live-rootfs.img"
  truncate -s "${rootfs_size}" "${rootfs_image}"
  mkfs.ext4 -F -L SoltrOSLive "${rootfs_image}" >/dev/null
fi

sudo modprobe loop
for loop_index in {0..7}; do
  if [[ ! -b "/dev/loop${loop_index}" ]]; then
    sudo mknod -m 0660 "/dev/loop${loop_index}" b 7 "${loop_index}"
    sudo chown root:disk "/dev/loop${loop_index}"
  fi
done
if [[ -n "${carrier_container}" ]]; then
  rootfs_mount="$(mktemp -d /tmp/soltros-live-rootfs-XXXXXX)"
  sudo mount -o loop "${rootfs_image}" "${rootfs_mount}"
  sudo rsync -aHAX --numeric-ids "${carrier_mount}/" "${rootfs_mount}/"
  sudo umount "${rootfs_mount}"
  rmdir "${rootfs_mount}"
  rootfs_mount=""
  sudo buildah unmount "${carrier_container}" >/dev/null
  carrier_mount=""
  sudo buildah rm "${carrier_container}" >/dev/null
  carrier_container=""
fi

label_live_rootfs

lorax_work_dir="${output_dir}/lorax-work-$$"
mkdir -p "${lorax_work_dir}/tmp"
if sudo podman image exists "${builder_cache_image}"; then
  builder_image="${builder_cache_image}"
else
  builder_container="soltros-live-media-builder-$$"
  builder_image="localhost/soltros-live-media-builder:${tag}-$$"
  builder_image_temporary="true"
  sudo buildah from --name "${builder_container}" "${live_builder_image}" >/dev/null
  mapfile -t live_builder_packages < <(jq -r '.live_media_builder.packages[]' "${source_lock}")
  sudo buildah run "${builder_container}" -- \
    dnf --disablerepo='*' --enablerepo=fedora --enablerepo=updates \
      install --assumeyes "${live_builder_packages[@]}"
  sudo buildah commit --rm "${builder_container}" "${builder_image}" >/dev/null
  builder_container=""
fi

sudo ionice -c 2 -n 7 nice -n 10 podman run \
  --rm \
  --privileged \
  --cpus "${build_cpus}" \
  --memory "${build_memory}" \
  --net host \
  --security-opt label=type:unconfined_t \
  -v "${rootfs_image}:/input/live-rootfs.img:rw" \
  -v "${repo_root}/disk_config/live-media.ks:/input/live-media.ks:ro" \
  -v "${lorax_work_dir}:/work" \
  "${builder_image}" \
  livemedia-creator \
    --make-iso \
    --fs-image=/input/live-rootfs.img \
    --ks=/input/live-media.ks \
    --no-virt \
    --compression="${compression}" \
    --project='SoltrOS Reborn' \
    --releasever="$(jq -er '.product.fedora_version' "${repo_root}/release/release.json")" \
    --volid="SOLTROS_REBORN_LIVE" \
    --iso-only \
    --iso-name="SoltrOS-${tag}-live-x86_64.iso" \
    --tmp=/work/tmp \
    --resultdir=/work/result

iso_name="SoltrOS-${tag}-live-x86_64.iso"
produced_iso="$(find "${lorax_work_dir}/result" -type f -name "${iso_name}" -print -quit)"
iso_path="${output_dir}/${iso_name}"
if [[ -z "${produced_iso}" ]]; then
  echo "LiveISO was not produced under ${lorax_work_dir}/result" >&2
  exit 1
fi
sudo mv "${produced_iso}" "${iso_path}"
sudo chown "$(id -u):$(id -g)" "${iso_path}"
sha256sum "${iso_path}" > "${iso_path}.sha256"
SOLTROS_OFFLINE_PAYLOAD_DIR="${payload_dir}" BUILD_ID="${BUILD_ID:-${tag}}" \
  "${repo_root}/tools/generate-release-artifacts.sh" "${iso_path}" "${output_dir}/release-artifacts"

printf 'ISO=%s\n' "${iso_path}"
printf 'CHECKSUM=%s\n' "${iso_path}.sha256"
