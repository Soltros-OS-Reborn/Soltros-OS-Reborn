#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/soltros-noctalia-theme-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
fake_bin="${test_root}/bin"
config_home="${test_root}/config"
mkdir -p "${fake_bin}" "${config_home}"

cat >"${fake_bin}/gsettings" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SOLTROS_GSETTINGS_LOG}"
EOF
cat >"${fake_bin}/pkill" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 0755 "${fake_bin}/gsettings" "${fake_bin}/pkill"

export PATH="${fake_bin}:${PATH}"
export HOME="${test_root}/home"
export XDG_CONFIG_HOME="${config_home}"
export XDG_RUNTIME_DIR="${test_root}/runtime"
export SOLTROS_GSETTINGS_LOG="${test_root}/gsettings.log"
mkdir -p "${HOME}" "${XDG_RUNTIME_DIR}"

NOCTALIA_THEME_MODE=dark "${repo_root}/system_files/usr/libexec/soltros/noctalia-theme-sync" dark
grep -Fxq 'set org.gnome.desktop.interface color-scheme prefer-dark' "${SOLTROS_GSETTINGS_LOG}"
grep -Fxq 'set org.gnome.desktop.interface gtk-theme Adwaita-dark' "${SOLTROS_GSETTINGS_LOG}"
grep -Fxq 'gtk-application-prefer-dark-theme=true' "${XDG_CONFIG_HOME}/gtk-3.0/settings.ini"
grep -Fxq 'gtk-theme-name=Adwaita-dark' "${XDG_CONFIG_HOME}/gtk-4.0/settings.ini"

NOCTALIA_THEME_MODE=light "${repo_root}/system_files/usr/libexec/soltros/noctalia-theme-sync" light
grep -Fxq 'set org.gnome.desktop.interface color-scheme prefer-light' "${SOLTROS_GSETTINGS_LOG}"
grep -Fxq 'gtk-theme-name=Adwaita' "${XDG_CONFIG_HOME}/gtk-4.0/settings.ini"
grep -Fxq 'gtk-application-prefer-dark-theme=false' "${XDG_CONFIG_HOME}/gtk-3.0/settings.ini"

printf 'PASS: Noctalia theme sync atomically updates GTK mode and settings\n'
