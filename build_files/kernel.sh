#!/usr/bin/env bash

set -euo pipefail

kernel_package="${KERNEL_PACKAGE:-kernel-cachyos}"
kernel_core_package="${kernel_package}-core"
installed_default_packages=()

for package in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra; do
  if rpm -q "${package}" >/dev/null 2>&1; then
    installed_default_packages+=("${package}")
  fi
done

if (( ${#installed_default_packages[@]} > 0 )); then
  printf 'layout=none\n' > /etc/kernel/install.conf
  dnf5 remove --no-autoremove -y "${installed_default_packages[@]}"
  rm -f /etc/kernel/install.conf
fi

dnf5 install -y "${kernel_package}"
rpm -q "${kernel_package}" "${kernel_core_package}"

kernel_version="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' \
  "${kernel_core_package}" | tail -n 1)"
kernel_modules="/usr/lib/modules/${kernel_version}"

if [[ ! -d "${kernel_modules}" ]] || [[ ! -s "${kernel_modules}/vmlinuz" ]]; then
  printf 'Installed kernel files are incomplete: %s\n' "${kernel_modules}" >&2
  exit 1
fi

printf 'Installed required kernel: %s\n' "${kernel_version}"
