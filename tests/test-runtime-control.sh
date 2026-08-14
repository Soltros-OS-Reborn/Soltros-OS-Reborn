#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/soltros-runtime-control-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
fake_root="${test_root}/root"
fake_bin="${test_root}/bin"
command_log="${test_root}/commands.log"
system_control="${repo_root}/system_files/usr/libexec/soltros/system.sh"

mkdir -p \
  "${fake_root}/usr/share/soltros" \
  "${fake_root}/usr/lib/soltros" \
  "${fake_root}/var/lib/soltros" \
  "${fake_root}/etc/containers" \
  "${fake_bin}"
cp "${repo_root}/release/release.json" "${fake_root}/usr/share/soltros/release.json"
cp "${repo_root}/release/sources.lock.json" "${fake_root}/usr/share/soltros/sources.lock.json"
cp "${repo_root}/variants/desktop-variants.json" "${fake_root}/usr/share/soltros/desktop-variants.json"
cp "${repo_root}/resources/policy.json" "${fake_root}/etc/containers/policy.json"
printf '%s\n' kde > "${fake_root}/usr/lib/soltros/desktop-variant"
jq -n '{update_ref:"ghcr.io/soltros-os-reborn/soltros-os:stable",update_source_configured:false}' \
  > "${fake_root}/var/lib/soltros/installation.json"

cat > "${fake_bin}/command-stub" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >> "${SOLTROS_COMMAND_LOG}"
if [[ "$(basename "$0")" == "flatpak" && -n "${SOLTROS_FAIL_FLATPAK:-}" ]]; then
  exit 9
fi
exit 0
EOF

cat > "${fake_bin}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'sudo %s\n' "$*" >> "${SOLTROS_COMMAND_LOG}"
"$@"
EOF

for command_name in bootc flatpak podman distrobox starship fwupdmgr flashrom mbpfan systemctl; do
  ln -s command-stub "${fake_bin}/${command_name}"
done
chmod 0755 "${fake_bin}/command-stub" "${fake_bin}/sudo"

export PATH="${fake_bin}:${PATH}"
export SOLTROS_COMMAND_LOG="${command_log}"
export SOLTROS_ROOT="${fake_root}"

"${system_control}" update >/dev/null
jq -e '.update_source_configured == true' \
  "${fake_root}/var/lib/soltros/installation.json" >/dev/null
"${system_control}" status >/dev/null
"${system_control}" update >/dev/null
"${system_control}" rollback >/dev/null
"${system_control}" doctor >/dev/null
"${system_control}" report > "${test_root}/report"

grep -Fq 'bootc upgrade' "${command_log}"
grep -Fq 'bootc switch ghcr.io/soltros-os-reborn/soltros-os:stable' "${command_log}"
grep -Fq 'bootc rollback' "${command_log}"
grep -Fq 'flatpak --system update --assumeyes' "${command_log}"
grep -Fq 'SoltrOS Reborn diagnostic report' "${test_root}/report"

if SOLTROS_FAIL_FLATPAK=1 "${system_control}" update \
    > "${test_root}/failed-update" 2>&1; then
  echo 'aggregate update must fail when a component update fails' >&2
  exit 1
fi
grep -Fq 'Update completed with 2 failed component(s).' "${test_root}/failed-update"

printf 'PASS: bootc runtime control, diagnostics, and failure reporting\n'
