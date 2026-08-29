#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
prepare_root="${repo_root}/resources/live/prepare-root.sh"
liveiso_builder="${repo_root}/disk_config/build-live-iso.sh"
test_root="$(mktemp -d /tmp/soltros-live-installer-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
catalog="${test_root}/catalog.json"
bin_dir="${test_root}/bin"
runtime_dir="${test_root}/runtime"
state_dir="${runtime_dir}/soltros-installer"
mkdir -p "${bin_dir}" "${runtime_dir}"

grep -Fq 'live_package_manifest=' "${prepare_root}"
grep -Fq 'grub2-efi-x64-cdboot' "${repo_root}/resources/live/packages.txt"
grep -Fq 'shim-x64' "${repo_root}/resources/live/packages.txt"
grep -Fq 'efi_grub_source=' "${prepare_root}"
grep -Fq "install -m 0700 \"\${efi_grub_source}\" /boot/efi/EFI/fedora/gcdx64.efi" "${prepare_root}"
if ! grep -Fq "kernel_source=\"/usr/lib/modules/\${kernel_version}/vmlinuz\"" "${prepare_root}" ||
    ! grep -Fq "install -m 0644 \"\${kernel_source}\" \"/boot/vmlinuz-\${kernel_version}\"" "${prepare_root}"; then
  printf 'LiveISO root preparation must stage the bootc kernel where Lorax can discover it\n' >&2
  exit 1
fi
grep -Fq 'for loop_index in {0..7}; do' "${liveiso_builder}"
grep -Fq 'LIVEISO_ROOTFS_IMAGE' "${liveiso_builder}"
grep -Fq 'offline_variant="${profile}"' "${liveiso_builder}"
grep -Fq 'SOLTROS_LIVE_VARIANT' "${liveiso_builder}"
grep -Fq 'systemctl enable gdm.service' "${prepare_root}"
grep -Fq 'systemctl enable greetd.service' "${prepare_root}"
grep -Fq 'graphical.target.wants/greetd.service' "${prepare_root}"
grep -Fq 'Insufficient free space for LiveISO build' "${liveiso_builder}"
grep -Fq 'sudo ionice -c 2 -n 7 nice -n 10 podman run' "${liveiso_builder}"
grep -Fq -- '--tmp=/work/tmp' "${liveiso_builder}"
grep -Fq -- '--resultdir=/work/result' "${liveiso_builder}"
grep -Fq 'label_live_rootfs() {' "${liveiso_builder}"
grep -Fq '/usr/sbin/setfiles -Fq /etc/selinux/targeted/contexts/files/file_contexts /' \
  "${liveiso_builder}"
grep -Fq "sudo tail -n 50 \"\${label_log}\" >&2" "${liveiso_builder}"
grep -Fq 'security.selinux' "${liveiso_builder}"
grep -Fq '/usr/lib/systemd/systemd' "${liveiso_builder}"

jq -n '{
  schema_version: 1,
  build_id: "installer-test",
  variant_count: 4,
  variants: [
    {
      variant: "kde",
      display_name: "KDE Plasma",
      source_ref: "oci:/usr/share/soltros/installer/oci:kde",
      source_digest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      update_ref: "ghcr.io/soltros-os-reborn/soltros-os:stable",
      online_updates_available: false
    },
    {
      variant: "gnome",
      display_name: "GNOME",
      source_ref: "oci:/usr/share/soltros/installer/oci:gnome",
      source_digest: "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      update_ref: "ghcr.io/soltros-os-reborn/soltros-os-gnome:stable",
      online_updates_available: false
    },
    {
      variant: "niri-dms",
      display_name: "Niri + Dank Material Shell",
      source_ref: "oci:/usr/share/soltros/installer/oci:niri-dms",
      source_digest: "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      update_ref: "ghcr.io/soltros-os-reborn/soltros-os-niri-dms:stable",
      online_updates_available: false
    },
    {
      variant: "niri-noctalia",
      display_name: "Niri + Noctalia",
      source_ref: "oci:/usr/share/soltros/installer/oci:niri-noctalia",
      source_digest: "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
      update_ref: "ghcr.io/soltros-os-reborn/soltros-os-niri-noctalia:stable",
      online_updates_available: false
    }
  ]
}' > "${catalog}"

cat > "${bin_dir}/kdialog" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *' --menu '* ]]; then
  printf 'kde\n'
fi
EOF

cat > "${bin_dir}/skopeo" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == inspect ]]; then
  printf 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n'
  exit 0
fi
exit 2
EOF

cat > "${bin_dir}/pkexec" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${XDG_RUNTIME_DIR}/soltros-installer/anaconda-command"
EOF
chmod 0755 "${bin_dir}"/*

SOLTROS_INSTALLER_CATALOG="${catalog}" \
XDG_RUNTIME_DIR="${runtime_dir}" \
KDIALOG="${bin_dir}/kdialog" \
SKOPEO="${bin_dir}/skopeo" \
PKEXEC="${bin_dir}/pkexec" \
LIVEINST=/usr/bin/liveinst \
  "${repo_root}/resources/live-install.sh"

jq -e '
  .variant == "kde" and
  .source_digest == "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and
  .update_ref == "ghcr.io/soltros-os-reborn/soltros-os:stable" and
  .build_id == "installer-test" and
  .installation_mode == "offline" and
  .update_source_configured == false and
  .oobe_required == true
' "${state_dir}/installation.json" >/dev/null

grep -Fq 'ostreecontainer --url oci:/usr/share/soltros/installer/oci:kde' \
  "${state_dir}/installation.ks"
grep -Fq '/usr/bin/liveinst --kickstart' "${state_dir}/anaconda-command"
grep -Fq '/var/lib/soltros/installation.json' "${state_dir}/installation.ks"

jq '.variants[0].online_updates_available = true' "${catalog}" > "${catalog}.online"
mv "${catalog}.online" "${catalog}"
printf '%s\n' '{}' > "${test_root}/policy.json"
rm -rf "${state_dir}"

cat > "${bin_dir}/kdialog" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *' --menu '* ]]; then
  printf 'kde\n'
elif [[ " $* " == *' --checklist '* ]]; then
  printf 'online\n'
fi
EOF

cat > "${bin_dir}/nm-online" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "${bin_dir}/skopeo" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == copy ]]; then
  printf '%s\n' "$*" > "${XDG_RUNTIME_DIR}/copy-command"
  exit 0
fi
if [[ "$1" == inspect ]]; then
  if [[ " $* " == *' docker://'* || " $* " == *'online-oci.part'* ]]; then
    printf 'sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\n'
  else
    printf 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n'
  fi
  exit 0
fi
exit 2
EOF
chmod 0755 "${bin_dir}"/*

SOLTROS_INSTALLER_CATALOG="${catalog}" \
SOLTROS_CONTAINER_POLICY="${test_root}/policy.json" \
XDG_RUNTIME_DIR="${runtime_dir}" \
KDIALOG="${bin_dir}/kdialog" \
NM_ONLINE="${bin_dir}/nm-online" \
SKOPEO="${bin_dir}/skopeo" \
PKEXEC="${bin_dir}/pkexec" \
LIVEINST=/usr/bin/liveinst \
  "${repo_root}/resources/live-install.sh"

jq -e '
  .variant == "kde" and
  .source_digest == "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" and
  .installation_mode == "online" and
  .oobe_required == true
' "${state_dir}/installation.json" >/dev/null
grep -Fq 'docker://ghcr.io/soltros-os-reborn/soltros-os:stable@sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee' \
  "${runtime_dir}/copy-command"
grep -Fq "oci:${state_dir}/online-oci:kde" "${state_dir}/installation.ks"
grep -Fqx 'installer-exited' "${state_dir}/state"

printf 'PASS: graphical installer verifies offline content and digest-pins optional online content\n'
