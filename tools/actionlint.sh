#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_lock="${repo_root}/release/sources.lock.json"

if command -v actionlint >/dev/null 2>&1; then
  exec actionlint "$@"
fi

case "$(uname -m)" in
  x86_64)
    archive_arch=amd64
    checksum_key=linux_amd64_sha256
    ;;
  aarch64)
    archive_arch=arm64
    checksum_key=linux_arm64_sha256
    ;;
  *)
    printf 'Unsupported actionlint architecture: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

version="$(jq -er '.actionlint.version' "${source_lock}")"
expected_sha256="$(jq -er --arg key "${checksum_key}" \
  '.actionlint[$key]' "${source_lock}")"
cache_root="${XDG_CACHE_HOME:-${HOME}/.cache}/soltros/tools"
binary="${cache_root}/actionlint-${version}-${archive_arch}"

if [[ ! -x "${binary}" ]]; then
  work_dir="$(mktemp -d /tmp/soltros-actionlint-XXXXXX)"
  trap 'rm -rf "${work_dir}"' EXIT
  archive="${work_dir}/actionlint.tar.gz"
  url="https://github.com/rhysd/actionlint/releases/download/v${version}/actionlint_${version}_linux_${archive_arch}.tar.gz"

  curl --fail --location --retry 3 --output "${archive}" "${url}"
  printf '%s  %s\n' "${expected_sha256}" "${archive}" | sha256sum --check --status
  tar -xzf "${archive}" -C "${work_dir}" actionlint
  mkdir -p "${cache_root}"
  install -m 0755 "${work_dir}/actionlint" "${binary}"
fi

exec "${binary}" "$@"
