#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/soltros-flatpak-test-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT

install_root="${test_root}/usr/share/soltros"
fake_bin="${test_root}/bin"
mkdir -p "${install_root}/bin" "${fake_bin}"
cp "${repo_root}/system_files/usr/share/soltros/bin/helper.sh" "${install_root}/bin/helper.sh"
cp "${repo_root}/repo_files/flatpaks" "${install_root}/flatpaks"

cat > "${fake_bin}/flatpak" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "remote-add" ]]; then
    exit 0
fi

if [[ "$#" -ge 4 && "$1" == "--system" && "$2" == "-y" && "$3" == "install" && "$4" == "--reinstall" ]]; then
    shift 4
    printf '%s\n' "$@" >> "${FLATPAK_INSTALL_LOG}"
    exit 0
fi

printf 'Unexpected flatpak arguments: %s\n' "$*" >&2
exit 1
EOF

cat > "${fake_bin}/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '404: Not Found'
EOF

chmod +x "${fake_bin}/flatpak" "${fake_bin}/curl"
export FLATPAK_INSTALL_LOG="${test_root}/installed-flatpaks"

PATH="${fake_bin}:${PATH}" bash "${install_root}/bin/helper.sh" install-flatpaks \
    > "${test_root}/helper-output" 2>&1

diff -u "${install_root}/flatpaks" "${FLATPAK_INSTALL_LOG}"
grep -Fq 'COPY repo_files/flatpaks /usr/share/soltros/flatpaks' "${repo_root}/Dockerfile"
if grep -Fq 'COPY repo_files/ /etc/yum.repos.d/' "${repo_root}/Dockerfile"; then
    echo 'Flatpak manifest must not be copied into /etc/yum.repos.d' >&2
    exit 1
fi

printf 'PASS: helper installed all %s bundled Flatpak IDs\n' "$(wc -l < "${FLATPAK_INSTALL_LOG}")"
