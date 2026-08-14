#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/soltros-user-defaults-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
fake_root="${test_root}/root"
migrator="${repo_root}/system_files/usr/libexec/soltros/migrate-user-defaults.sh"

mkdir -p \
  "${fake_root}/usr/lib/soltros" \
  "${fake_root}/usr/share/soltros/defaults/niri-noctalia/.config/niri"
cp "${repo_root}/release/release.json" "${fake_root}/usr/share/soltros/release.json"
printf '%s\n' niri-noctalia > "${fake_root}/usr/lib/soltros/desktop-variant"
printf '%s\n' 'version-one' > \
  "${fake_root}/usr/share/soltros/defaults/niri-noctalia/.config/niri/config.kdl"

fresh_home="${test_root}/fresh-home"
mkdir -p "${fresh_home}"
HOME="${fresh_home}" SOLTROS_ROOT="${fake_root}" "${migrator}"
grep -Fxq 'version-one' "${fresh_home}/.config/niri/config.kdl"

jq '.user_defaults.version = 2' "${fake_root}/usr/share/soltros/release.json" \
  > "${fake_root}/usr/share/soltros/release.json.new"
mv "${fake_root}/usr/share/soltros/release.json.new" \
  "${fake_root}/usr/share/soltros/release.json"
printf '%s\n' 'version-two' > \
  "${fake_root}/usr/share/soltros/defaults/niri-noctalia/.config/niri/config.kdl"
HOME="${fresh_home}" SOLTROS_ROOT="${fake_root}" "${migrator}"
grep -Fxq 'version-two' "${fresh_home}/.config/niri/config.kdl"
grep -Fxq 'version-one' \
  "${fresh_home}/.local/state/soltros/user-defaults/backups/1-to-2/.config/niri/config.kdl"

custom_home="${test_root}/custom-home"
mkdir -p "${custom_home}/.config/niri"
printf '%s\n' 'custom-shortcuts' > "${custom_home}/.config/niri/config.kdl"
HOME="${custom_home}" SOLTROS_ROOT="${fake_root}" "${migrator}"
grep -Fxq 'custom-shortcuts' "${custom_home}/.config/niri/config.kdl"
grep -Fxq 'version-two' "${custom_home}/.config/niri/config.kdl.soltros-new"
grep -Fxq 'custom-shortcuts' \
  "${custom_home}/.local/state/soltros/user-defaults/backups/unmanaged-to-2/.config/niri/config.kdl"

printf 'PASS: versioned user defaults preserve and back up customizations\n'
