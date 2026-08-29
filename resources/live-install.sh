#!/usr/bin/env bash

set -euo pipefail

catalog="${SOLTROS_INSTALLER_CATALOG:-/usr/share/soltros/installer/catalog.json}"
policy="${SOLTROS_CONTAINER_POLICY:-/etc/containers/policy.json}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state_dir="${SOLTROS_INSTALLER_STATE_DIR:-${runtime_dir}/soltros-installer}"
kdialog_command="${KDIALOG:-kdialog}"
skopeo_command="${SKOPEO:-skopeo}"
pkexec_command="${PKEXEC:-pkexec}"
liveinst_command="${LIVEINST:-/usr/bin/liveinst}"
nm_online_command="${NM_ONLINE:-nm-online}"
state_file="${state_dir}/state"
online_staging_dir="${state_dir}/online-oci.part"

mkdir -p "${state_dir}"

write_state() {
  printf '%s\n' "$1" > "${state_file}"
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  rm -rf "${online_staging_dir}"
  if (( status != 0 )); then
    write_state failed
  fi
  exit "${status}"
}
trap cleanup EXIT INT TERM

show_error() {
  "${kdialog_command}" --title 'SoltrOS Reborn Installer' --error "$1" || true
}

if [[ ! -r "${catalog}" ]]; then
  show_error "The offline installer catalog is unavailable: ${catalog}"
  exit 1
fi

if ! jq -e '
    .schema_version == 1 and
    (.build_id | type == "string" and length > 0) and
    (.variant_count == (.variants | length)) and
    (.variant_count > 0) and
    all(.variants[];
      (.variant | test("^[a-z0-9-]+$")) and
      (.source_ref | startswith("oci:/")) and
      (.source_digest | test("^sha256:[0-9a-f]{64}$")) and
      (.update_ref | test("^[a-z0-9.-]+/[a-z0-9._/-]+:[a-z0-9._-]+$")) and
      (.online_updates_available | type == "boolean"))
  ' "${catalog}" >/dev/null; then
  show_error 'The offline installer catalog is invalid.'
  exit 1
fi

menu_arguments=()
while IFS=$'\t' read -r variant display_name; do
  menu_arguments+=("${variant}" "${display_name}")
done < <(jq -r '.variants[] | [.variant, .display_name] | @tsv' "${catalog}")

if ! selected_variant="$("${kdialog_command}" \
    --title 'Install SoltrOS Reborn' \
    --menu 'Choose the desktop environment to install:' \
    "${menu_arguments[@]}")"; then
  write_state cancelled
  exit 0
fi
write_state selected

entry="$(jq -cer --arg variant "${selected_variant}" \
  '.variants[] | select(.variant == $variant)' "${catalog}")" || {
    show_error 'The selected desktop is not present in the installer catalog.'
    exit 1
  }

source_ref="$(jq -er '.source_ref' <<<"${entry}")"
source_digest="$(jq -er '.source_digest' <<<"${entry}")"
update_ref="$(jq -er '.update_ref' <<<"${entry}")"
online_updates_available="$(jq -r '.online_updates_available' <<<"${entry}")"
build_id="$(jq -er '.build_id' "${catalog}")"
install_mode=offline

actual_digest="$("${skopeo_command}" inspect --format '{{.Digest}}' "${source_ref}")" || {
  show_error 'The embedded desktop image could not be read.'
  exit 1
}
if [[ "${actual_digest}" != "${source_digest}" ]]; then
  show_error 'The embedded desktop image failed its digest check.'
  exit 1
fi

if [[ "${online_updates_available}" == true ]]; then
  online_ready=false
  online_selection=''
  remote_digest=''
  write_state preflight
  if "${nm_online_command}" -q --timeout=5 >/dev/null 2>&1 &&
      [[ -r "${policy}" ]] &&
      remote_digest="$("${skopeo_command}" inspect \
        --policy "${policy}" \
        --format '{{.Digest}}' \
        "docker://${update_ref}" 2>/dev/null)" &&
      [[ "${remote_digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    online_ready=true
  fi

  if [[ "${online_ready}" == true ]]; then
    if ! online_selection="$("${kdialog_command}" \
        --title 'Optional Online Update' \
        --separate-output \
        --checklist \
        'The embedded image is ready for offline installation. Optionally select the item below to download and verify the newest stable image.' \
        online 'Use the newest signed stable image' off)"; then
      write_state cancelled
      exit 0
    fi

    if [[ "${online_selection}" == online ]]; then
      rm -rf "${online_staging_dir}"
      mkdir -p "${online_staging_dir}"
      write_state copying-update
      if "${skopeo_command}" copy \
          --policy "${policy}" \
          "docker://${update_ref}@${remote_digest}" \
          "oci:${online_staging_dir}:${selected_variant}"; then
        copied_digest="$("${skopeo_command}" inspect \
          --format '{{.Digest}}' \
          "oci:${online_staging_dir}:${selected_variant}")"
        if [[ "${copied_digest}" == "${remote_digest}" ]]; then
          rm -rf "${state_dir}/online-oci"
          mv "${online_staging_dir}" "${state_dir}/online-oci"
          source_ref="oci:${state_dir}/online-oci:${selected_variant}"
          source_digest="${copied_digest}"
          install_mode=online
        else
          rm -rf "${online_staging_dir}"
          show_error 'The downloaded image failed its digest check. The embedded image will be used.'
        fi
      else
        rm -rf "${online_staging_dir}"
        show_error 'The signed online image could not be downloaded. The embedded image will be used.'
      fi
    fi
  fi
fi

metadata="${state_dir}/installation.json"
kickstart="${state_dir}/installation.ks"

jq -n \
  --arg variant "${selected_variant}" \
  --arg source_digest "${source_digest}" \
  --arg update_ref "${update_ref}" \
  --arg build_id "${build_id}" \
  --arg install_mode "${install_mode}" \
  '{
    schema_version: 1,
    variant: $variant,
    source_digest: $source_digest,
    update_ref: $update_ref,
    build_id: $build_id,
    installation_mode: $install_mode,
    update_source_configured: false,
    oobe_required: true
  }' > "${metadata}"

cat > "${kickstart}" <<EOF
graphical
autopart --type=plain
ostreecontainer --url ${source_ref}

%post --nochroot
target_root=/mnt/sysroot
if [ ! -d "\${target_root}" ]; then
    target_root=/mnt/sysimage
fi
install -D -m 0644 ${metadata} \
    "\${target_root}/var/lib/soltros/installation.json"
%end
EOF

write_state ready
write_state installer-running
"${pkexec_command}" "${liveinst_command}" --kickstart "${kickstart}"
write_state installer-exited
