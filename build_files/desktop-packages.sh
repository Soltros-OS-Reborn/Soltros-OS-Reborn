#!/usr/bin/bash

set ${SET_X:+-x} -eou pipefail

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

package_manifest_root=/ctx/packages
mapfile -t package_manifests < <(find "${package_manifest_root}" -type f -name '*.txt' -print | sort)
if (( ${#package_manifests[@]} == 0 )); then
    echo "No package manifests found in ${package_manifest_root}" >&2
    exit 1
fi

mapfile -t layered_packages < <(
    sed -e '/^[[:space:]]*$/d' "${package_manifests[@]}" | sort -u
)

if (( ${#layered_packages[@]} == 0 )); then
    echo 'Package manifests are empty' >&2
    exit 1
fi

dnf5 install --setopt=install_weak_deps=False -y "${layered_packages[@]}"

for required_package in "${layered_packages[@]}"; do
    if ! rpm -q --whatprovides "${required_package}" >/dev/null; then
        echo "Required package was not installed: ${required_package}" >&2
        exit 1
    fi
done

log "Setting up DisplayPort audio suspend/resume fix"

# Make the systemd-sleep script executable
chmod +x /usr/lib/systemd/system-sleep/soltros-audio-resume

# Verify the script is in place
if [ -f "/usr/lib/systemd/system-sleep/soltros-audio-resume" ]; then
    echo "DisplayPort audio resume script installed successfully"
else
    echo "Warning: DisplayPort audio resume script not found"
fi

dnf5 remove -y firefox firefox-* || true
