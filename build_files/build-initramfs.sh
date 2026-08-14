#!/usr/bin/bash

set -euo pipefail

kernel_package="${KERNEL_PACKAGE:-kernel-cachyos}"
kernel_core_package="${kernel_package}-core"
kernel_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' \
  "${kernel_core_package}" | tail -n 1)"
kernel_modules="/usr/lib/modules/${kernel_version}"
initramfs="${kernel_modules}/initramfs.img"

if [[ ! -d "${kernel_modules}" ]] || [[ ! -s "${kernel_modules}/vmlinuz" ]]; then
  printf 'Required kernel files are missing: %s\n' "${kernel_modules}" >&2
  exit 1
fi

dracut --no-hostonly --kver "${kernel_version}" --reproducible --zstd \
  --add ostree --force "${initramfs}"
chmod 0600 "${initramfs}"

if [[ ! -s "${initramfs}" ]]; then
  printf 'Initramfs was not generated: %s\n' "${initramfs}" >&2
  exit 1
fi

printf 'Built initramfs for %s\n' "${kernel_version}"
