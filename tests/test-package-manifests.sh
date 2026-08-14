#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_root="${repo_root}/build_files/packages"
installer="${repo_root}/build_files/desktop-packages.sh"
all_packages="$(mktemp /tmp/soltros-packages-XXXXXX)"
trap 'rm -f "${all_packages}"' EXIT

find "${manifest_root}" -type f -name '*.txt' -print0 | sort -z | xargs -0 cat > "${all_packages}"

if [[ ! -s "${all_packages}" ]]; then
  echo 'package manifests are empty' >&2
  exit 1
fi

duplicates="$(sort "${all_packages}" | uniq -d)"
if [[ -n "${duplicates}" ]]; then
  printf 'duplicate packages found:\n%s\n' "${duplicates}" >&2
  exit 1
fi

for forbidden_package in gimp gamemode-devel libvirtd ptyxis; do
  if grep -Fxq "${forbidden_package}" "${all_packages}"; then
    printf 'package belongs in a desktop or optional application profile: %s\n' \
      "${forbidden_package}" >&2
    exit 1
  fi
done

grep -Fq "rpm -q --whatprovides \"\${required_package}\"" "${installer}"
if rg -n -- '--nogpgcheck|--skip-unavailable' "${installer}" >/dev/null; then
  echo 'package installation bypasses a required integrity check' >&2
  exit 1
fi

if [[ -e "${repo_root}/system_files/etc/udev/rules.d/99-gaming-devices.rules" ]] ||
    [[ -e "${repo_root}/system_files/etc/tmpfiles.d/gaming-cpu.conf" ]]; then
  echo 'unsafe global gaming overrides must not be installed' >&2
  exit 1
fi

printf 'PASS: declarative package layers are unique and fail-closed\n'
