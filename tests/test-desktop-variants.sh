#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${repo_root}/variants/desktop-variants.json"
dockerfile="${repo_root}/Dockerfile"
build_entry="${repo_root}/build_files/build.sh"
workflow="${repo_root}/.github/workflows/build.yml"
renovate_config="${repo_root}/.github/renovate.json5"
policy="${repo_root}/resources/policy.json"
signing_script="${repo_root}/build_files/signing.sh"
overlay_script="${repo_root}/build_files/apply-desktop-files.sh"
rpmdb_repair_script="${repo_root}/build_files/repair-rpmdb.sh"
test_root="$(mktemp -d /tmp/soltros-desktop-variants-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
failures=0
fedora_version="$(jq -er '.product.fedora_version | tostring' "${repo_root}/release/release.json")"

fail() {
    printf '%s\n' "$1" >&2
    failures=$((failures + 1))
}

if [[ ! -f "${manifest}" ]] || ! jq -e --arg fedora_version "${fedora_version}" '
    length == 4 and
    ([.[].id] | sort == ["gnome", "kde", "niri-dms", "niri-noctalia"]) and
    ([.[].image_name] | unique | length == 4) and
    all(.[];
        (.id | type == "string") and
        (.display_name | type == "string") and
        (.base_image | startswith("quay.io/fedora/")) and
        (.base_tag == $fedora_version) and
        (.base_digest | test("^sha256:[0-9a-f]{64}$")) and
        (.image_name | startswith("soltros-os")) and
        (.session | type == "string") and
        (.display_manager | type == "string")
    )
' "${manifest}" >/dev/null 2>&1; then
    fail 'desktop variant manifest must define four complete, unique variants'
fi

if ! grep -Fq 'desktop-variants\\.json' "${renovate_config}" ||
    ! grep -Fq 'currentDigest' "${renovate_config}"; then
    fail 'Renovate must refresh digest-pinned Fedora desktop base images'
fi

for variant in kde gnome niri-dms niri-noctalia; do
    script="${repo_root}/build_files/desktops/${variant}.sh"
    if [[ ! -x "${script}" ]]; then
        fail "desktop build script is missing or not executable: ${variant}"
    fi
done

if ! grep -Fq 'ARG DESKTOP_VARIANT=kde' "${dockerfile}" ||
    ! grep -Fq 'BUILD_PHASE=common bash /ctx/build.sh' "${dockerfile}" ||
    ! grep -Fq 'BUILD_PHASE=desktop bash /ctx/build.sh' "${dockerfile}"; then
    fail 'Dockerfile must pass the selected desktop variant into the build entry point'
fi

if ! grep -Fq '/ctx/repair-rpmdb.sh' "${dockerfile}" ||
    ! grep -Fq 'rpmdb --exportdb' "${rpmdb_repair_script}" ||
    ! grep -Fq -- '--importdb' "${rpmdb_repair_script}" ||
    ! grep -Fq -- '--verifydb' "${rpmdb_repair_script}" ||
    ! grep -Fq "'filesystem(unmerged-sbin-symlinks)'" "${rpmdb_repair_script}" ||
    ! grep -Fq "'libuuid.so.1()(64bit)'" "${rpmdb_repair_script}" ||
    ! grep -Fq "'group(tss)'" "${rpmdb_repair_script}"; then
    fail 'Image builds must repair and validate RPM capability indexes before publication'
fi

grep -Fq 'FROM soltros-common AS soltros' "${dockerfile}" ||
    fail 'Dockerfile must isolate the shared system stage from desktop stages'

if ! grep -Fq 'desktop_files/' "${dockerfile}" ||
    ! grep -Fq '/ctx/apply-desktop-files.sh' "${dockerfile}"; then
    fail 'Dockerfile must apply common and variant-specific desktop files'
fi

package_line="$(grep -nF 'echo_group /ctx/desktop-packages.sh' "${build_entry}" | cut -d: -f1)"
overlay_line="$(grep -nF 'echo_group /ctx/apply-desktop-files.sh /ctx/desktop-files' "${build_entry}" | cut -d: -f1)"
if [[ -z "${package_line}" || -z "${overlay_line}" || "${overlay_line}" -le "${package_line}" ]]; then
    fail 'desktop files must be applied after package installation'
fi

if ! grep -Fq "DESKTOP_VARIANT=\"\${DESKTOP_VARIANT:-kde}\"" "${build_entry}" ||
    ! grep -Fq "/ctx/desktops/\${DESKTOP_VARIANT}.sh" "${build_entry}"; then
    fail 'build entry point must validate and dispatch the selected desktop variant'
fi

if grep -Eq '^[[:space:]]+(sddm|gdm|gnome-boxes|gnome-tweaks)[[:space:]]*$' \
    "${repo_root}/build_files/desktop-packages.sh"; then
    fail 'desktop-specific packages must not remain in the common package layer'
fi

grep -Fq 'kde-desktop' "${repo_root}/build_files/desktops/kde.sh" ||
    fail 'KDE variant must install the KDE desktop group'
grep -Eq 'plasmalogin|sddm' "${repo_root}/build_files/desktops/kde.sh" ||
    fail 'KDE variant must configure a KDE display manager'
grep -Fq 'gnome-desktop' "${repo_root}/build_files/desktops/gnome.sh" ||
    fail 'GNOME variant must install the GNOME desktop group'
grep -Fq 'gdm.service' "${repo_root}/build_files/desktops/gnome.sh" ||
    fail 'GNOME variant must enable GDM'
grep -Fq '/ctx/desktops/niri-common.sh' "${repo_root}/build_files/desktops/niri-dms.sh" ||
    fail 'Niri DMS variant must use the shared Niri layer'
grep -Fq 'dms.service' "${repo_root}/build_files/desktops/niri-dms.sh" ||
    fail 'Niri DMS variant must enable the DMS user service'
if grep -Fq 'spawn-at-startup "dms"' \
    "${repo_root}/desktop_files/niri-dms/etc/skel/.config/niri/soltros-shell.kdl"; then
    fail 'Niri DMS variant must not start DMS twice'
fi
grep -Fq '/ctx/desktops/niri-common.sh' "${repo_root}/build_files/desktops/niri-noctalia.sh" ||
    fail 'Niri Noctalia variant must use the shared Niri layer'
grep -Fq 'noctalia' "${repo_root}/build_files/desktops/niri-noctalia.sh" ||
    fail 'Niri Noctalia variant must install Noctalia'

for path in \
    desktop_files/niri-common/etc/greetd/config.toml \
    desktop_files/niri-dms/etc/skel/.config/niri/soltros-shell.kdl \
    desktop_files/niri-noctalia/etc/skel/.config/niri/soltros-shell.kdl; do
    [[ -f "${repo_root}/${path}" ]] || fail "desktop file overlay is missing: ${path}"
done

for variant in kde gnome niri-dms niri-noctalia; do
    target_root="${test_root}/${variant}"
    SOLTROS_VARIANT_MANIFEST="${manifest}" DESKTOP_VARIANT="${variant}" \
      "${overlay_script}" \
        "${repo_root}/desktop_files" "${target_root}"

    case "${variant}" in
        kde)
            [[ ! -e "${target_root}/etc/greetd/config.toml" ]] ||
                fail 'KDE overlay must not contain Niri files'
            ;;
        gnome)
            [[ -f "${target_root}/etc/dconf/db/local.d/00-soltros-settings" ]] ||
                fail 'GNOME overlay must contain GNOME defaults'
            [[ ! -e "${target_root}/etc/greetd/config.toml" ]] ||
                fail 'GNOME overlay must not contain Niri files'
            ;;
        niri-dms)
            [[ -f "${target_root}/etc/greetd/config.toml" ]] ||
                fail 'Niri DMS overlay must contain shared Niri files'
            grep -Fq 'dms" "ipc"' \
                "${target_root}/etc/skel/.config/niri/soltros-shell.kdl" ||
                fail 'Niri DMS overlay must contain DMS bindings'
            ;;
        niri-noctalia)
            [[ -f "${target_root}/etc/greetd/config.toml" ]] ||
                fail 'Niri Noctalia overlay must contain shared Niri files'
            grep -Fq 'spawn-at-startup "soltros-noctalia-session" "--daemon"' \
                "${target_root}/etc/skel/.config/niri/soltros-shell.kdl" ||
                fail 'Niri Noctalia overlay must start Noctalia'
            ;;
    esac
done

if SOLTROS_VARIANT_MANIFEST="${manifest}" DESKTOP_VARIANT=unknown \
    "${overlay_script}" \
    "${repo_root}/desktop_files" "${test_root}/unknown" >/dev/null 2>&1; then
    fail 'desktop file application must reject unknown variants'
fi

if ! grep -Fq 'release/generated/desktop-matrix.json' "${workflow}" ||
    ! grep -Fq "DESKTOP_VARIANT=\${{ matrix.desktop.id }}" "${workflow}" ||
    ! grep -Fq "BASE_REF=\${{ matrix.desktop.base_image }}@\${{ matrix.desktop.base_digest }}" "${workflow}"; then
    fail 'CI must consume the generated digest-pinned desktop matrix'
fi

for image_name in $(jq -r '.[].image_name' "${manifest}"); do
    image_ref="ghcr.io/soltros-os-reborn/${image_name}"
    jq -e --arg image_ref "${image_ref}" \
        '.transports.docker[$image_ref][0].type == "sigstoreSigned" and
         (.transports.docker[$image_ref][0].keyPaths | length >= 1)' \
        "${policy}" >/dev/null ||
        fail "signing policy is missing desktop image: ${image_ref}"
done

grep -Fq '/ctx/policy.json' "${signing_script}" ||
    fail 'image signing setup must install the generated trust policy'

jq -e '.default[0].type == "insecureAcceptAnything"' "${policy}" >/dev/null ||
    fail 'signing policy must preserve ordinary Podman, Toolbox, and Distrobox pulls'

if [[ "${failures}" -ne 0 ]]; then
    exit 1
fi

printf 'PASS: four isolated desktop image variants are wired through build files and CI\n'
