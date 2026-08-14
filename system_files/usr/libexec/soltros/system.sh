#!/usr/bin/env bash

set -euo pipefail

root="${SOLTROS_ROOT:-}"
data_dir="${SOLTROS_DATA_DIR:-${root}/usr/share/soltros}"
variant_file="${root}/usr/lib/soltros/desktop-variant"
policy_file="${root}/etc/containers/policy.json"
installation_file="${root}/var/lib/soltros/installation.json"
failures=0

info() {
  printf '[INFO] %s\n' "$*"
}

pass() {
  printf '[PASS] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  failures=$((failures + 1))
}

run_update_step() {
  local name="$1"
  shift

  info "${name}"
  if "$@"; then
    pass "${name}"
  else
    fail "${name}"
  fi
}

require_command() {
  local command_name="$1"

  if command -v "${command_name}" >/dev/null 2>&1; then
    pass "Command available: ${command_name}"
  else
    fail "Command missing: ${command_name}"
  fi
}

show_status() {
  if ! command -v bootc >/dev/null 2>&1; then
    fail 'bootc is not installed'
    return 1
  fi

  if [[ -r "${variant_file}" ]]; then
    printf 'Desktop variant: %s\n' "$(<"${variant_file}")"
  else
    warn "Desktop variant marker is missing: ${variant_file}"
  fi

  bootc status
}

update_system() {
  local update_ref updated_metadata

  if ! command -v bootc >/dev/null 2>&1; then
    fail 'bootc is not installed'
  elif [[ -r "${installation_file}" ]] &&
      jq -e '.update_source_configured == false' "${installation_file}" >/dev/null; then
    update_ref="$(jq -er '.update_ref' "${installation_file}")"
    info "Configure signed bootc update source: ${update_ref}"
    if sudo bootc switch "${update_ref}"; then
      updated_metadata="$(mktemp /tmp/soltros-installation-XXXXXX.json)"
      jq '.update_source_configured = true' "${installation_file}" > "${updated_metadata}"
      sudo install -m 0644 "${updated_metadata}" "${installation_file}"
      rm -f "${updated_metadata}"
      pass 'Signed bootc update source configured'
    else
      fail 'Configure signed bootc update source'
    fi
  else
    run_update_step 'Upgrade bootc deployment' sudo bootc upgrade
  fi

  if command -v flatpak >/dev/null 2>&1; then
    run_update_step 'Update system Flatpaks' flatpak --system update --assumeyes
    run_update_step 'Update user Flatpaks' flatpak --user update --assumeyes
  else
    warn 'Flatpak is not installed; skipping application updates'
  fi

  if command -v distrobox >/dev/null 2>&1; then
    run_update_step 'Update Distrobox containers' distrobox upgrade --all
  fi

  if (( failures > 0 )); then
    printf 'Update completed with %d failed component(s).\n' "${failures}" >&2
    return 1
  fi

  pass 'All requested update components completed successfully'
}

rollback_system() {
  if ! command -v bootc >/dev/null 2>&1; then
    fail 'bootc is not installed'
    return 1
  fi

  sudo bootc rollback
  pass 'Rollback deployment selected; reboot to enter it'
}

check_policy() {
  local variant="$1"
  local registry image_name image_ref

  if [[ ! -r "${policy_file}" ]]; then
    fail "Containers policy is missing: ${policy_file}"
    return
  fi

  if jq -e '.default[0].type == "insecureAcceptAnything"' \
      "${policy_file}" >/dev/null; then
    pass 'Ordinary container pulls remain available'
  else
    fail 'Containers policy blocks ordinary Podman, Toolbox, or Distrobox pulls'
  fi

  registry="$(jq -er '.publication.registry' "${data_dir}/release.json")"
  image_name="$(jq -er --arg id "${variant}" \
    '.[] | select(.id == $id) | .image_name' \
    "${data_dir}/desktop-variants.json")"
  image_ref="${registry}/${image_name}"
  if jq -e --arg image_ref "${image_ref}" \
      '.transports.docker[$image_ref][0].type == "sigstoreSigned" and
       (.transports.docker[$image_ref][0].keyPaths | length >= 1)' \
      "${policy_file}" >/dev/null; then
    pass "Signed update policy: ${image_ref}"
  else
    fail "Signed update policy is missing: ${image_ref}"
  fi
}

doctor() {
  local variant display_manager service

  for command_name in bootc flatpak podman distrobox starship fwupdmgr flashrom mbpfan jq; do
    require_command "${command_name}"
  done

  for manifest in release.json desktop-variants.json sources.lock.json; do
    if [[ -r "${data_dir}/${manifest}" ]]; then
      pass "Manifest readable: ${manifest}"
    else
      fail "Manifest missing: ${data_dir}/${manifest}"
    fi
  done

  if [[ ! -r "${variant_file}" ]]; then
    fail "Desktop variant marker is missing: ${variant_file}"
  else
    variant="$(<"${variant_file}")"
    if jq -e --arg id "${variant}" 'any(.[]; .id == $id)' \
        "${data_dir}/desktop-variants.json" >/dev/null; then
      pass "Desktop variant: ${variant}"
      display_manager="$(jq -er --arg id "${variant}" \
        '.[] | select(.id == $id) | .display_manager' \
        "${data_dir}/desktop-variants.json")"
      service="${display_manager}.service"
      if systemctl is-enabled "${service}" >/dev/null 2>&1; then
        pass "Display manager enabled: ${service}"
      else
        fail "Display manager is not enabled: ${service}"
      fi
      check_policy "${variant}"
    else
      fail "Unknown desktop variant marker: ${variant}"
    fi
  fi

  for service in mbpfan.service thermald.service; do
    if systemctl is-enabled "${service}" >/dev/null 2>&1; then
      pass "Service enabled: ${service}"
    else
      fail "Service is not enabled: ${service}"
    fi
  done

  if command -v bootc >/dev/null 2>&1 && bootc status >/dev/null; then
    pass 'bootc deployment status is readable'
  else
    fail 'bootc deployment status is not readable'
  fi

  if (( failures > 0 )); then
    printf 'Doctor found %d blocking issue(s).\n' "${failures}" >&2
    return 1
  fi

  pass 'SoltrOS system contracts are healthy'
}

report() {
  printf 'SoltrOS Reborn diagnostic report\n'
  printf 'Generated: %s\n' "$(date --utc --iso-8601=seconds)"
  printf 'Kernel: %s\n' "$(uname -srmo)"
  if [[ -r "${root}/etc/os-release" ]]; then
    grep -E '^(PRETTY_NAME|VERSION_ID)=' "${root}/etc/os-release"
  fi
  printf '\nDeployment\n'
  show_status || true
  printf '\nHealth\n'
  doctor || true
}

case "${1:-}" in
  status)
    show_status
    ;;
  update)
    update_system
    ;;
  rollback)
    rollback_system
    ;;
  doctor)
    doctor
    ;;
  report)
    report
    ;;
  *)
    printf 'Usage: %s {status|update|rollback|doctor|report}\n' "$0" >&2
    exit 2
    ;;
esac
