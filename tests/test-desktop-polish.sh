#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${repo_root}/variants/desktop-variants.json"
overlay_script="${repo_root}/build_files/apply-desktop-files.sh"
state_dir_argument="--state-dir \"\${state_dir}\""
test_root="$(mktemp -d /tmp/soltros-desktop-polish-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT

assert_file() {
  local path="$1"
  [[ -f "${path}" ]] || {
    printf 'expected file is missing: %s\n' "${path}" >&2
    exit 1
  }
}

grep -Fq 'apply_layer shared' "${overlay_script}"
grep -Fq 'cp -a /etc/skel/.config/.' "${repo_root}/build_files/install-user-defaults.sh"
jq -e '.user_defaults.version == 5' "${repo_root}/release/release.json" >/dev/null

overlay_line="$(grep -nF 'echo_group /ctx/apply-desktop-files.sh /ctx/desktop-files' \
  "${repo_root}/build_files/build.sh" | cut -d: -f1)"
defaults_line="$(grep -nF 'echo_group /ctx/desktop-defaults.sh' \
  "${repo_root}/build_files/build.sh" | cut -d: -f1)"
[[ -n "${overlay_line}" && -n "${defaults_line}" && "${overlay_line}" -lt "${defaults_line}" ]] || {
  echo 'desktop defaults must run after the variant overlay is applied' >&2
  exit 1
}

for variant in kde gnome niri-dms niri-noctalia; do
  target_root="${test_root}/${variant}"
  SOLTROS_VARIANT_MANIFEST="${manifest}" DESKTOP_VARIANT="${variant}" \
    "${overlay_script}" "${repo_root}/desktop_files" "${target_root}"

  assert_file "${target_root}/etc/xdg/gtk-3.0/settings.ini"
  assert_file "${target_root}/etc/xdg/gtk-4.0/settings.ini"
  assert_file "${target_root}/usr/share/backgrounds/soltros-reborn/electric-blue.svg"
  assert_file "${target_root}/usr/share/backgrounds/soltros-reborn/electric-blue.png"
  assert_file "${target_root}/etc/skel/.config/starship.toml"
  assert_file "${target_root}/etc/skel/.config/fastfetch/config.jsonc"
  assert_file "${target_root}/etc/skel/.config/btop/btop.conf"
  assert_file "${target_root}/etc/skel/.config/btop/themes/SoltrOS.theme"
  grep -Fxq 'gtk-icon-theme-name=Papirus-Dark' \
    "${target_root}/etc/xdg/gtk-3.0/settings.ini"
  grep -Fxq 'gtk-theme-name=Adwaita-dark' \
    "${target_root}/etc/xdg/gtk-4.0/settings.ini"
done

grep -Fxq 'fastfetch' "${repo_root}/build_files/packages/core.txt"
grep -Fxq 'jetbrains-mono-fonts-all' "${repo_root}/build_files/packages/core.txt"
grep -Fxq 'palette = "soltros"' \
  "${repo_root}/desktop_files/shared/etc/skel/.config/starship.toml"

gnome_root="${test_root}/gnome"
grep -Fxq "accent-color='blue'" \
  "${gnome_root}/etc/dconf/db/local.d/00-soltros-settings"
grep -Fxq "color-scheme='prefer-dark'" \
  "${gnome_root}/etc/dconf/db/local.d/00-soltros-settings"
assert_file "${gnome_root}/usr/share/gnome-background-properties/soltros-reborn.xml"

kde_root="${test_root}/kde"
grep -Fxq 'ColorScheme=BreezeDark' "${kde_root}/etc/skel/.config/kdeglobals"
grep -Fxq 'Theme=Papirus-Dark' "${kde_root}/etc/skel/.config/kdeglobals"
grep -Fxq 'name=breeze-dark' "${kde_root}/etc/skel/.config/plasmarc"
assert_file "${kde_root}/etc/skel/.local/share/konsole/SoltrOS.colorscheme"
assert_file "${kde_root}/etc/skel/.config/autostart/org.soltros.InitialWallpaper.desktop"
grep -Fxq 'Font=JetBrains Mono,11,-1,5,50,0,0,0,0,0,Regular' \
  "${kde_root}/etc/skel/.local/share/konsole/SoltrOS.profile"

grep -Fxq "monospace-font-name='JetBrains Mono 11'" \
  "${gnome_root}/etc/dconf/db/local.d/00-soltros-settings"

for variant in niri-dms niri-noctalia; do
  niri_root="${test_root}/${variant}"
  grep -Fq 'spawn-at-startup "swaybg"' \
    "${niri_root}/etc/skel/.config/niri/config.kdl"
  grep -Fq 'active-color "#4c9aff"' \
    "${niri_root}/etc/skel/.config/niri/config.kdl"
  grep -Fq 'border {' "${niri_root}/etc/skel/.config/niri/config.kdl"
  grep -Fq 'softness 16' "${niri_root}/etc/skel/.config/niri/config.kdl"
  assert_file "${niri_root}/etc/skel/.config/fuzzel/fuzzel.ini"
  grep -Fq 'Quick Launcher' "${niri_root}/etc/skel/.config/niri/config.kdl"
  assert_file "${niri_root}/etc/skel/.config/alacritty/alacritty.toml"
  assert_file "${niri_root}/etc/skel/.config/alacritty/soltros-base-theme.toml"
  grep -Fxq 'background = "#14161b"' \
    "${niri_root}/etc/skel/.config/alacritty/soltros-base-theme.toml"
done

dms_root="${test_root}/niri-dms"
noctalia_root="${test_root}/niri-noctalia"
[[ ! -e "${dms_root}/etc/skel/.config/noctalia/noctalia-config.toml" ]] || {
  echo 'Niri DMS overlay must not contain Noctalia settings' >&2
  exit 1
}
assert_file "${dms_root}/usr/lib/systemd/user/soltros-dms-palette.service"
assert_file "${dms_root}/etc/skel/.config/kitty/kitty.conf"
grep -Fxq 'include dank-theme.conf' "${dms_root}/etc/skel/.config/kitty/kitty.conf"
grep -Fq 'dank-theme.toml' "${dms_root}/etc/skel/.config/alacritty/alacritty.toml"
grep -Fxq 'After=dms.service' \
  "${dms_root}/usr/lib/systemd/user/soltros-dms-palette.service"
grep -Fq 'soltros-dms-palette.service' \
  "${repo_root}/build_files/desktop-defaults.sh"
assert_file "${noctalia_root}/etc/skel/.config/noctalia/noctalia-config.toml"
grep -Fxq 'mode = "dark"' \
  "${noctalia_root}/etc/skel/.config/noctalia/noctalia-config.toml"
grep -Fxq 'source = "wallpaper"' \
  "${noctalia_root}/etc/skel/.config/noctalia/noctalia-config.toml"

grep -Fq 'swaybg' "${repo_root}/build_files/desktops/niri-common.sh"
test -x "${repo_root}/system_files/usr/libexec/soltros/apply-initial-wallpaper"
grep -Fq 'plasma-apply-wallpaperimage' \
  "${repo_root}/system_files/usr/libexec/soltros/apply-initial-wallpaper"
grep -Fq 'SOLTROS_WALLPAPER:-/usr/share/backgrounds/soltros-reborn/electric-blue.png' \
  "${repo_root}/system_files/usr/libexec/soltros/apply-initial-wallpaper"
test -x "${repo_root}/system_files/usr/libexec/soltros/apply-initial-dms-palette"
grep -Fq 'dms matugen generate' \
  "${repo_root}/system_files/usr/libexec/soltros/apply-initial-dms-palette"
grep -Fq 'SOLTROS_WALLPAPER:-/usr/share/backgrounds/soltros-reborn/electric-blue.png' \
  "${repo_root}/system_files/usr/libexec/soltros/apply-initial-dms-palette"
grep -Fq -- '--shell-dir /usr/share/quickshell/dms' \
  "${repo_root}/system_files/usr/libexec/soltros/apply-initial-dms-palette"
grep -Fq -- "${state_dir_argument}" \
  "${repo_root}/system_files/usr/libexec/soltros/apply-initial-dms-palette"

dms_test_root="${test_root}/dms-command-contract"
dms_home="${dms_test_root}/home"
dms_config="${dms_test_root}/config"
dms_state="${dms_test_root}/state"
dms_wallpaper="${dms_test_root}/electric-blue.png"
dms_arguments="${dms_test_root}/arguments"
dms_calls="${dms_test_root}/calls"
mkdir -p "${dms_home}" "${dms_config}" "${dms_state}"
touch "${dms_wallpaper}"

dms() {
  printf '%s\n' "$@" > "${DMS_ARGUMENTS}"
  printf 'called\n' >> "${DMS_CALLS}"
}

export -f dms
export DMS_ARGUMENTS="${dms_arguments}"
export DMS_CALLS="${dms_calls}"
HOME="${dms_home}" \
XDG_CONFIG_HOME="${dms_config}" \
XDG_STATE_HOME="${dms_state}" \
SOLTROS_WALLPAPER="${dms_wallpaper}" \
  "${repo_root}/system_files/usr/libexec/soltros/apply-initial-dms-palette"

test -f "${dms_state}/soltros/dms-palette-v1"
grep -Fxq 'matugen' "${dms_arguments}"
grep -Fxq -- '--config-dir' "${dms_arguments}"
grep -Fxq "${dms_config}" "${dms_arguments}"
grep -Fxq -- '--state-dir' "${dms_arguments}"
grep -Fxq "${dms_state}/soltros/dms" "${dms_arguments}"
grep -Fxq -- '--terminals-always-dark' "${dms_arguments}"

HOME="${dms_home}" \
XDG_CONFIG_HOME="${dms_config}" \
XDG_STATE_HOME="${dms_state}" \
SOLTROS_WALLPAPER="${dms_wallpaper}" \
  "${repo_root}/system_files/usr/libexec/soltros/apply-initial-dms-palette"
test "$(wc -l < "${dms_calls}")" -eq 1

printf 'PASS: dark-blue desktop defaults are shared, native, and variant-isolated\n'
