#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
package_root="${repo_root}/build_files/packages"
motd="${repo_root}/system_files/etc/motd"
soltros="${repo_root}/system_files/usr/bin/soltros"
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

if [[ "${failures}" -ne 0 ]]; then
    exit 1
fi

printf 'PASS: Fedora 44 package, command wrapper, and static MOTD contracts\n'
