#!/usr/bin/env bash

set -euo pipefail

root="${SOLTROS_ROOT:-}"
data_dir="${SOLTROS_DATA_DIR:-${root}/usr/share/soltros}"
variant_file="${root}/usr/lib/soltros/desktop-variant"
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/soltros/user-defaults"

if [[ ! -r "${variant_file}" ]] || [[ ! -r "${data_dir}/release.json" ]]; then
  exit 0
fi

variant="$(<"${variant_file}")"
version="$(jq -er '.user_defaults.version' "${data_dir}/release.json")"
defaults="${data_dir}/defaults/${variant}"
current_version_file="${state_root}/current-version"

if [[ ! -d "${defaults}" ]]; then
  exit 0
fi

if [[ -r "${current_version_file}" ]] &&
    [[ "$(<"${current_version_file}")" == "${version}" ]]; then
  exit 0
fi

previous_version=""
if [[ -r "${current_version_file}" ]]; then
  previous_version="$(<"${current_version_file}")"
fi

backup_root="${state_root}/backups/${previous_version:-unmanaged}-to-${version}"
previous_root="${state_root}/versions/${previous_version}"
new_state_root="${state_root}/versions/${version}"

while IFS= read -r -d '' source_file; do
  relative_path="${source_file#"${defaults}"/}"
  target_file="${HOME}/${relative_path}"
  previous_file="${previous_root}/${relative_path}"
  backup_file="${backup_root}/${relative_path}"
  state_file="${new_state_root}/${relative_path}"

  mkdir -p "$(dirname -- "${state_file}")"
  cp -a "${source_file}" "${state_file}"

  if [[ ! -e "${target_file}" ]]; then
    mkdir -p "$(dirname -- "${target_file}")"
    cp -a "${source_file}" "${target_file}"
    continue
  fi

  mkdir -p "$(dirname -- "${backup_file}")"
  cp -a "${target_file}" "${backup_file}"

  if cmp --silent "${target_file}" "${source_file}"; then
    continue
  fi

  if [[ -n "${previous_version}" ]] && [[ -f "${previous_file}" ]] &&
      cmp --silent "${target_file}" "${previous_file}"; then
    cp -a "${source_file}" "${target_file}"
  else
    cp -a "${source_file}" "${target_file}.soltros-new"
  fi
done < <(find "${defaults}" -type f -print0 | sort -z)

mkdir -p "${state_root}"
printf '%s\n' "${version}" > "${current_version_file}"
