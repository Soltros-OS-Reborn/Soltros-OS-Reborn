#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
package_root="${repo_root}/build_files/packages"
motd="${repo_root}/system_files/etc/motd"
soltros="${repo_root}/system_files/usr/bin/soltros"
kernel_script="${repo_root}/build_files/kernel.sh"
failures=0

if rg -n -F 'fwupd-plugin-flashrom' "${package_root}" >/dev/null; then
    printf 'obsolete fwupd-plugin-flashrom package remains in the Fedora 44 package list\n' >&2
    failures=$((failures + 1))
fi
if ! rg -l -x 'flashrom' "${package_root}" >/dev/null; then
    printf 'standalone flashrom package is missing from the Fedora 44 package list\n' >&2
    failures=$((failures + 1))
fi

if [[ ! -x "${soltros}" ]] || ! grep -Fq 'exec /usr/bin/bash /usr/share/soltros/bin/helper.sh "$@"' "${soltros}"; then
    printf 'executable soltros command wrapper is missing\n' >&2
    failures=$((failures + 1))
fi

if grep -Eq '^(#!|[A-Z_][A-Z_0-9]*=|.*\$\(|[[:space:]]*(echo|cat|uptime|free)[[:space:]])' "${motd}"; then
    printf '/etc/motd must contain rendered text, not executable shell source\n' >&2
    failures=$((failures + 1))
fi
if ! grep -Fq 'soltros help' "${motd}"; then
    printf '/etc/motd must advertise the installed soltros command\n' >&2
    failures=$((failures + 1))
fi

layout_line="$(grep -nF "printf 'layout=none\\n' > /etc/kernel/install.conf" "${kernel_script}" | cut -d: -f1)"
install_line="$(grep -nF "dnf5 install -y \"\${kernel_package}\"" "${kernel_script}" | cut -d: -f1)"
restore_line="$(grep -nF 'rm -f /etc/kernel/install.conf' "${kernel_script}" | tail -n 1 | cut -d: -f1)"
if [[ -z "${layout_line}" || -z "${install_line}" || -z "${restore_line}" ]] ||
    (( layout_line >= install_line || restore_line <= install_line )); then
    printf 'kernel installation must suppress transaction-time initramfs generation\n' >&2
    failures=$((failures + 1))
fi
if ! grep -Fq "depmod -a \"\${kernel_version}\"" "${kernel_script}"; then
    printf 'kernel installation must generate module dependency metadata before initramfs\n' >&2
    failures=$((failures + 1))
fi

if [[ "${failures}" -ne 0 ]]; then
    exit 1
fi

printf 'PASS: Fedora 44 package, command wrapper, and static MOTD contracts\n'
