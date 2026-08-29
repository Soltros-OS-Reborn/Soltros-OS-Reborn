#!/usr/bin/bash

set ${SET_X:+-x} -euo pipefail

log() {
  echo "=== $* ==="
}

DESTDIR="${1:-/out}"
SOURCE_LOCK="${2:-/usr/share/soltros/sources.lock.json}"

if [[ ! -r "${SOURCE_LOCK}" ]]; then
  echo "Source lock is not readable: ${SOURCE_LOCK}" >&2
  exit 1
fi

STARSHIP_VERSION="$(jq -er '.starship.version' "${SOURCE_LOCK}")"
MBPFAN_VERSION="$(jq -er '.mbpfan.version' "${SOURCE_LOCK}")"
YAZI_VERSION="$(jq -er '.yazi.version' "${SOURCE_LOCK}")"
MOREWAITA_COMMIT="$(jq -er '.morewaita.commit' "${SOURCE_LOCK}")"
DESKTOP_VARIANT="${DESKTOP_VARIANT:-kde}"

case "$(uname -m)" in
  x86_64)
    STARSHIP_TARGET="x86_64-unknown-linux-gnu"
    STARSHIP_SHA256="$(jq -er '.starship.x86_64_unknown_linux_gnu_sha256' "${SOURCE_LOCK}")"
    ;;
  aarch64)
    STARSHIP_TARGET="aarch64-unknown-linux-musl"
    STARSHIP_SHA256="$(jq -er '.starship.aarch64_unknown_linux_musl_sha256' "${SOURCE_LOCK}")"
    ;;
  *)
    echo "Unsupported architecture for the pinned Starship release: $(uname -m)" >&2
    exit 1
    ;;
esac

MBPFAN_SHA256="$(jq -er '.mbpfan.source_sha256' "${SOURCE_LOCK}")"
MOREWAITA_SHA256="$(jq -er '.morewaita.source_sha256' "${SOURCE_LOCK}")"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

download_verified() {
  local url="$1"
  local expected_sha256="$2"
  local output="$3"

  aria2c \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --check-integrity=false \
    --connect-timeout=30 \
    --file-allocation=none \
    --max-connection-per-server=8 \
    --max-tries=3 \
    --min-split-size=1M \
    --out="$(basename -- "$output")" \
    --dir="$(dirname -- "$output")" \
    --retry-wait=5 \
    --split=8 \
    --timeout=60 \
    "$url"
  printf '%s  %s\n' "$expected_sha256" "$output" | sha256sum --check --status
}

log "Installing Starship ${STARSHIP_VERSION}"
STARSHIP_ARCHIVE="$WORKDIR/starship.tar.gz"
download_verified \
  "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-${STARSHIP_TARGET}.tar.gz" \
  "$STARSHIP_SHA256" \
  "$STARSHIP_ARCHIVE"
mkdir -p "$WORKDIR/starship"
tar -xzf "$STARSHIP_ARCHIVE" -C "$WORKDIR/starship"
install -D -m 0755 "$WORKDIR/starship/starship" "$DESTDIR/usr/bin/starship"

log "Building mbpfan ${MBPFAN_VERSION}"
MBPFAN_ARCHIVE="$WORKDIR/mbpfan.tar"
MBPFAN_REPO="$WORKDIR/mbpfan-repo"
git init -q "$MBPFAN_REPO"
git -C "$MBPFAN_REPO" remote add origin https://github.com/linux-on-mac/mbpfan.git
git -C "$MBPFAN_REPO" fetch --quiet --depth 1 origin "refs/tags/v${MBPFAN_VERSION}"
git -C "$MBPFAN_REPO" archive --format=tar --prefix="mbpfan-${MBPFAN_VERSION}/" \
  FETCH_HEAD >"$MBPFAN_ARCHIVE"
printf '%s  %s\n' "$MBPFAN_SHA256" "$MBPFAN_ARCHIVE" | sha256sum --check --status
tar -xf "$MBPFAN_ARCHIVE" -C "$WORKDIR"
MBPFAN_SOURCE="$WORKDIR/mbpfan-${MBPFAN_VERSION}"
make -C "$MBPFAN_SOURCE"
install -D -m 0755 "$MBPFAN_SOURCE/bin/mbpfan" "$DESTDIR/usr/bin/mbpfan"
install -D -m 0644 "$MBPFAN_SOURCE/mbpfan.service" "$DESTDIR/usr/lib/systemd/system/mbpfan.service"
install -D -m 0644 "$MBPFAN_SOURCE/mbpfan.depend.conf" "$DESTDIR/usr/lib/modules-load.d/mbpfan.conf"
install -D -m 0644 "$MBPFAN_SOURCE/mbpfan.8.gz" "$DESTDIR/usr/share/man/man8/mbpfan.8.gz"
install -D -m 0644 "$MBPFAN_SOURCE/COPYING" "$DESTDIR/usr/share/licenses/mbpfan/COPYING"

case "$(uname -m)" in
  x86_64)
    YAZI_TARGET="x86_64-unknown-linux-gnu"
    YAZI_SHA256="$(jq -er '.yazi.x86_64_unknown_linux_gnu_sha256' "${SOURCE_LOCK}")"
    ;;
  aarch64)
    YAZI_TARGET="aarch64-unknown-linux-gnu"
    YAZI_SHA256="$(jq -er '.yazi.aarch64_unknown_linux_gnu_sha256' "${SOURCE_LOCK}")"
    ;;
  *)
    echo "Unsupported architecture for the pinned Yazi release: $(uname -m)" >&2
    exit 1
    ;;
esac

log "Installing Yazi ${YAZI_VERSION}"
YAZI_ARCHIVE="$WORKDIR/yazi.zip"
download_verified \
  "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-${YAZI_TARGET}.zip" \
  "$YAZI_SHA256" \
  "$YAZI_ARCHIVE"
mkdir -p "$WORKDIR/yazi"
unzip -q "$YAZI_ARCHIVE" -d "$WORKDIR/yazi"
YAZI_SOURCE="$WORKDIR/yazi/yazi-${YAZI_TARGET}"
test -x "$YAZI_SOURCE/yazi"
test -x "$YAZI_SOURCE/ya"
install -D -m 0755 "$YAZI_SOURCE/yazi" "$DESTDIR/usr/bin/yazi"
install -D -m 0755 "$YAZI_SOURCE/ya" "$DESTDIR/usr/bin/ya"
install -D -m 0644 "$YAZI_SOURCE/LICENSE" \
  "$DESTDIR/usr/share/licenses/yazi/LICENSE"
install -D -m 0644 "$YAZI_SOURCE/completions/yazi.bash" \
  "$DESTDIR/usr/share/bash-completion/completions/yazi"
install -D -m 0644 "$YAZI_SOURCE/completions/ya.bash" \
  "$DESTDIR/usr/share/bash-completion/completions/ya"
install -D -m 0644 "$YAZI_SOURCE/completions/yazi.fish" \
  "$DESTDIR/usr/share/fish/vendor_completions.d/yazi.fish"
install -D -m 0644 "$YAZI_SOURCE/completions/ya.fish" \
  "$DESTDIR/usr/share/fish/vendor_completions.d/ya.fish"
install -D -m 0644 "$YAZI_SOURCE/completions/_yazi" \
  "$DESTDIR/usr/share/zsh/site-functions/_yazi"
install -D -m 0644 "$YAZI_SOURCE/completions/_ya" \
  "$DESTDIR/usr/share/zsh/site-functions/_ya"

log "Installing optional MoreWaita icon theme"
MOREWAITA_ARCHIVE="$WORKDIR/morewaita.tar"
MOREWAITA_REPO="$WORKDIR/morewaita-repo"
git init -q "$MOREWAITA_REPO"
git -C "$MOREWAITA_REPO" remote add origin https://github.com/somepaulo/MoreWaita.git
git -C "$MOREWAITA_REPO" fetch --quiet --depth 1 origin "$MOREWAITA_COMMIT"
git -C "$MOREWAITA_REPO" archive --format=tar \
  --prefix="MoreWaita-${MOREWAITA_COMMIT}/" "$MOREWAITA_COMMIT" >"$MOREWAITA_ARCHIVE"
printf '%s  %s\n' "$MOREWAITA_SHA256" "$MOREWAITA_ARCHIVE" | sha256sum --check --status
tar -xf "$MOREWAITA_ARCHIVE" -C "$WORKDIR"
MOREWAITA_SOURCE="$WORKDIR/MoreWaita-${MOREWAITA_COMMIT}"
MOREWAITA_DEST="$DESTDIR/usr/share/icons/MoreWaita"
install -d "$MOREWAITA_DEST"
cp -a "$MOREWAITA_SOURCE/index.theme" "$MOREWAITA_SOURCE/scalable" \
  "$MOREWAITA_SOURCE/symbolic" "$MOREWAITA_DEST/"
install -D -m 0644 "$MOREWAITA_SOURCE/LICENSE" \
  "$DESTDIR/usr/share/licenses/MoreWaita/LICENSE"
install -D -m 0644 "$MOREWAITA_SOURCE/README.md" \
  "$DESTDIR/usr/share/doc/MoreWaita/README.md"
install -D -m 0644 "$MOREWAITA_SOURCE/AUTHORS" \
  "$DESTDIR/usr/share/doc/MoreWaita/AUTHORS"
gtk-update-icon-cache -f -t "$MOREWAITA_DEST"

if [[ "$DESKTOP_VARIANT" == kde ]]; then
  KMYC_VERSION="$(jq -er '.kde_material_you_colors.version' "${SOURCE_LOCK}")"
  log "Installing KDE Material You Colors ${KMYC_VERSION}"
  KMYC_URL="$(jq -er '.kde_material_you_colors.wheel_url' "${SOURCE_LOCK}")"
  KMYC_SHA256="$(jq -er '.kde_material_you_colors.wheel_sha256' "${SOURCE_LOCK}")"
  MATERIALYOUCOLOR_URL="$(jq -er '.kde_material_you_colors.materialyoucolor_url' "${SOURCE_LOCK}")"
  MATERIALYOUCOLOR_SHA256="$(jq -er '.kde_material_you_colors.materialyoucolor_sha256' "${SOURCE_LOCK}")"
  KMYC_DEST="$DESTDIR/usr/lib/soltros/kde-material-you-colors"
  KMYC_ARCHIVE="$WORKDIR/kde-material-you-colors.whl"
  MATERIALYOUCOLOR_ARCHIVE="$WORKDIR/materialyoucolor.tar.gz"
  download_verified "$KMYC_URL" "$KMYC_SHA256" "$KMYC_ARCHIVE"
  download_verified "$MATERIALYOUCOLOR_URL" "$MATERIALYOUCOLOR_SHA256" "$MATERIALYOUCOLOR_ARCHIVE"
  install -d "$KMYC_DEST"
  unzip -q "$KMYC_ARCHIVE" -d "$KMYC_DEST"
  tar -xzf "$MATERIALYOUCOLOR_ARCHIVE" -C "$WORKDIR"
  cp -a "$WORKDIR/materialyoucolor-3.0.4/materialyoucolor" "$KMYC_DEST/"
  install -D -m 0755 /dev/stdin "$DESTDIR/usr/bin/kde-material-you-colors" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
home_dir="${HOME:?HOME is required}"
if [[ -L "${home_dir}" && ! -e "${home_dir}" ]]; then
  mkdir -p -- "$(dirname -- "${home_dir}")/$(readlink -- "${home_dir}")"
fi
mkdir -p "${home_dir}/.local/share"
export PYTHONPATH=/usr/lib/soltros/kde-material-you-colors${PYTHONPATH:+:${PYTHONPATH}}
exec python3 -c 'from kde_material_you_colors.main import main; main()' "$@"
EOF
  install -D -m 0644 "$KMYC_DEST/kde_material_you_colors-2.2.0.dist-info/licenses/LICENSE" \
    "$DESTDIR/usr/share/licenses/kde-material-you-colors/LICENSE"
  install -D -m 0644 "$WORKDIR/materialyoucolor-3.0.4/LICENSE" \
    "$DESTDIR/usr/share/licenses/materialyoucolor/LICENSE"
fi

if [[ "$DESKTOP_VARIANT" == niri-dms ]]; then
  GHOSTTY_VERSION="$(jq -er '.ghostty.version' "${SOURCE_LOCK}")"
  log "Installing optional Pywalfox native host"
  PYWALFOX_URL="$(jq -er '.pywalfox.wheel_url' "${SOURCE_LOCK}")"
  PYWALFOX_SHA256="$(jq -er '.pywalfox.wheel_sha256' "${SOURCE_LOCK}")"
  PYWALFOX_ARCHIVE="$WORKDIR/pywalfox.whl"
  PYWALFOX_DEST="$DESTDIR/usr/lib/soltros/pywalfox"
  download_verified "$PYWALFOX_URL" "$PYWALFOX_SHA256" "$PYWALFOX_ARCHIVE"
  install -d "$PYWALFOX_DEST"
  unzip -q "$PYWALFOX_ARCHIVE" -d "$PYWALFOX_DEST"
  install -D -m 0755 /dev/stdin "$DESTDIR/usr/bin/pywalfox" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
pywalfox_root=/usr/lib/soltros/pywalfox
if [[ ! -d "$pywalfox_root" && -d /out/usr/lib/soltros/pywalfox ]]; then
  pywalfox_root=/out/usr/lib/soltros/pywalfox
fi
export PYTHONPATH="$pywalfox_root${PYTHONPATH:+:${PYTHONPATH}}"
exec python3 -m pywalfox "$@"
EOF
  install -D -m 0644 "$PYWALFOX_DEST/pywalfox-2.9.0.dist-info/licenses/LICENSE" \
    "$DESTDIR/usr/share/licenses/pywalfox/LICENSE"

  log "Building optional Ghostty ${GHOSTTY_VERSION}"
  GHOSTTY_URL="$(jq -er '.ghostty.source_url' "${SOURCE_LOCK}")"
  GHOSTTY_SHA256="$(jq -er '.ghostty.source_sha256' "${SOURCE_LOCK}")"
  GHOSTTY_SIG_URL="$(jq -er '.ghostty.minisig_url' "${SOURCE_LOCK}")"
  GHOSTTY_SIG_SHA256="$(jq -er '.ghostty.minisig_sha256' "${SOURCE_LOCK}")"
  GHOSTTY_KEY="$(jq -er '.ghostty.minisign_public_key' "${SOURCE_LOCK}")"
  GHOSTTY_ARCHIVE="$WORKDIR/ghostty.tar.gz"
  GHOSTTY_SIG="$WORKDIR/ghostty.tar.gz.minisig"
  download_verified "$GHOSTTY_URL" "$GHOSTTY_SHA256" "$GHOSTTY_ARCHIVE"
  download_verified "$GHOSTTY_SIG_URL" "$GHOSTTY_SIG_SHA256" "$GHOSTTY_SIG"
  minisign -Vm "$GHOSTTY_ARCHIVE" -x "$GHOSTTY_SIG" -P "$GHOSTTY_KEY"
  case "$(uname -m)" in
    x86_64)
      ZIG_URL="$(jq -er '.ghostty.zig_x86_64_url' "${SOURCE_LOCK}")"
      ZIG_SHA256="$(jq -er '.ghostty.zig_x86_64_sha256' "${SOURCE_LOCK}")"
      ZIG_DIR="zig-x86_64-linux-0.15.2"
      ;;
    aarch64)
      ZIG_URL="$(jq -er '.ghostty.zig_aarch64_url' "${SOURCE_LOCK}")"
      ZIG_SHA256="$(jq -er '.ghostty.zig_aarch64_sha256' "${SOURCE_LOCK}")"
      ZIG_DIR="zig-aarch64-linux-0.15.2"
      ;;
    *)
      echo "Unsupported architecture for Ghostty: $(uname -m)" >&2
      exit 1
      ;;
  esac
  ZIG_ARCHIVE="$WORKDIR/zig.tar.xz"
  download_verified "$ZIG_URL" "$ZIG_SHA256" "$ZIG_ARCHIVE"
  tar -xJf "$ZIG_ARCHIVE" -C "$WORKDIR"
  GHOSTTY_SOURCE="$WORKDIR/ghostty-${GHOSTTY_VERSION}"
  tar -xzf "$GHOSTTY_ARCHIVE" -C "$WORKDIR"
  dnf5 -y install blueprint-compiler gcc-c++ gettext gtk4-devel gtk4-layer-shell-devel \
    libadwaita-devel minisign oniguruma-devel pandoc pkgconf-pkg-config xz
  (
    cd "$GHOSTTY_SOURCE"
    export PATH="$WORKDIR/$ZIG_DIR:$PATH"
    export ZIG_GLOBAL_CACHE_DIR="$WORKDIR/zig-cache"
    mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
    fetch_failed=0
    while IFS= read -r dependency_url; do
      dependency_fetched=0
      for attempt in 1 2 3 4 5; do
        if zig fetch "$dependency_url" >/dev/null 2>&1; then
          dependency_fetched=1
          break
        fi
        sleep $((attempt * 2))
      done
      if (( dependency_fetched == 0 )); then
        echo "Failed to fetch Ghostty dependency: $dependency_url" >&2
        fetch_failed=1
        break
      fi
    done < build.zig.zon.txt
    (( fetch_failed == 0 ))
    DESTDIR="$DESTDIR" zig build --prefix /usr --system "$ZIG_GLOBAL_CACHE_DIR/p" \
      -Doptimize=ReleaseFast -Dcpu=baseline
  )
  install -D -m 0644 "$GHOSTTY_SOURCE/LICENSE" \
    "$DESTDIR/usr/share/licenses/ghostty/LICENSE"
fi

log "Third-party tools installed"
STARSHIP_CACHE="$WORKDIR/starship-cache" "$DESTDIR/usr/bin/starship" --version
"$DESTDIR/usr/bin/mbpfan" -h
"$DESTDIR/usr/bin/yazi" --version
"$DESTDIR/usr/bin/ya" --version
if [[ "$DESKTOP_VARIANT" == niri-dms ]]; then
  "$DESTDIR/usr/bin/pywalfox" --version
  test -x "$DESTDIR/usr/bin/ghostty"
fi
