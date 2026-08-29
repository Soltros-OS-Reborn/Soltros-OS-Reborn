#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/soltros-installer-config-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
workflow="${repo_root}/.github/workflows/build.yml"
live_installer="${repo_root}/resources/live-install.sh"
liveiso_builder="${repo_root}/disk_config/build-live-iso.sh"

grep -Fq 'disk_config/build-live-iso.sh "artifacts/${{ matrix.profile }}" "${{ matrix.profile }}"' "${workflow}"
grep -Fq 'profile: [online, kde, gnome, niri-dms, niri-noctalia]' "${workflow}"
grep -Fq 'artifacts/${{ matrix.profile }}/**/*.iso' "${workflow}"
grep -Fq 'artifacts/${{ matrix.profile }}/**/*.sha256' "${workflow}"
grep -Fq 'artifacts/${{ matrix.profile }}/**/release-artifacts/*' "${workflow}"
grep -Fq 'ostreecontainer --url' "${live_installer}"
grep -Fq 'source_digest' "${live_installer}"
grep -Fq 'online_updates_available' "${live_installer}"
grep -Fq -- "\"\${pkexec_command}\" \"\${liveinst_command}\" --kickstart" "${live_installer}"
grep -Fq 'build-offline-payload.sh' "${liveiso_builder}"
grep -Fq 'OFFLINE_VARIANT' "${liveiso_builder}"
grep -Fq 'Unsupported LiveISO profile' "${liveiso_builder}"
grep -Fq 'sudo modprobe loop' "${liveiso_builder}"
grep -Fq "output_dir=\"\$(cd -- \"\${output_dir}\" && pwd)\"" \
  "${liveiso_builder}"
grep -Fq 'livemedia-creator' "${liveiso_builder}"
grep -Fq -- '--make-iso' "${liveiso_builder}"
grep -Fq -- '--fs-image=/input/live-rootfs.img' "${liveiso_builder}"
grep -Fq -- '--ks=/input/live-media.ks' "${liveiso_builder}"
grep -Fq -- '--no-virt' "${liveiso_builder}"
grep -Fq "compression=\"\${LIVEISO_COMPRESSION:-xz}\"" "${liveiso_builder}"
grep -Fq -- "--compression=\"\${compression}\"" "${liveiso_builder}"
grep -Fq 'part / --fstype=ext4' "${repo_root}/disk_config/live-media.ks"
grep -Fq 'dracut-live' "${repo_root}/disk_config/live-media.ks"
grep -Fq 'dracut-live' "${repo_root}/resources/live/packages.txt"
grep -Fq 'bootloader --append="selinux=0"' "${repo_root}/disk_config/live-media.ks"
grep -Fq 'anaconda-live' "${repo_root}/resources/live/packages.txt"
grep -Fq 'live_package_manifest=' "${repo_root}/resources/live/prepare-root.sh"
grep -Fq 'NetworkManager' "${repo_root}/resources/live/packages.txt"
grep -Fq 'enablerepo=fedora-cisco-openh264' "${repo_root}/resources/live/prepare-root.sh"
grep -Fq 'firefox' "${repo_root}/resources/live/packages.txt"
grep -Fqx 'gdisk' "${repo_root}/resources/live/packages.txt"
grep -Fq 'lshw' "${repo_root}/resources/live/packages.txt"
grep -Fq 'buildah from' "${liveiso_builder}"

if grep -Fqx 'gptfdisk' "${repo_root}/resources/live/packages.txt"; then
  printf 'live package manifest contains the obsolete gptfdisk package name\n' >&2
  exit 1
fi

mkdir -p "${test_root}/bin" "${test_root}/artifacts"
cat > "${test_root}/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${SUDO_LOG:?}"
exit 73
EOF
chmod 0755 "${test_root}/bin/sudo"

set +e
PATH="${test_root}/bin:${PATH}" \
SUDO_LOG="${test_root}/sudo.log" \
IMAGE_REGISTRY=registry.example.test/soltros \
LIVEISO_MIN_FREE_BYTES=1 \
  "${liveiso_builder}" "${test_root}/artifacts" >"${test_root}/liveiso.log" 2>&1
liveiso_status=$?
set -e
test "${liveiso_status}" -eq 73
grep -Fq 'podman pull registry.example.test/soltros/soltros-os:dev' \
  "${test_root}/sudo.log"

grep -Fq 'catalog.json' "${repo_root}/resources/live-install.sh"
grep -Fq "online 'Use the newest signed stable image' off" \
  "${repo_root}/resources/live-install.sh"
grep -Fq 'nm_online_command=' "${repo_root}/resources/live-install.sh"
grep -Fq 'online-oci.part' "${repo_root}/resources/live-install.sh"
grep -Fq "docker://\${update_ref}@\${remote_digest}" "${repo_root}/resources/live-install.sh"

if grep -Eq -- '--(image|target|add-file)([[:space:]]|$)' "${live_installer}"; then
  printf 'live installer contains obsolete bootc install arguments\n' >&2
  exit 1
fi

printf 'PASS: LiveISO config offers four manifest-backed desktop choices\n'
