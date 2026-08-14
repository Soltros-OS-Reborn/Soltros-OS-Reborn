#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

"${repo_root}/tools/validate-release.sh"

jq -e '.publication.enabled == false and .publication.repository_ready == false' \
  "${repo_root}/release/release.json" >/dev/null

for workflow in build promote release; do
  if grep -Fq "if: \${{ false }}" "${repo_root}/.github/workflows/${workflow}.yml"; then
    echo "release workflow is still a disabled placeholder: ${workflow}" >&2
    exit 1
  fi
done
grep -Fq 'release/release.json' "${repo_root}/.github/workflows/promote.yml"
grep -Fq 'release/release.json' "${repo_root}/.github/workflows/release.yml"
grep -Fq 'cosign verify-attestation' "${repo_root}/.github/workflows/build.yml"
grep -Fq 'gh release create' "${repo_root}/.github/workflows/release.yml"

container_cosign_commands="$(rg '^[[:space:]]+cosign (sign|verify|attest|verify-attestation) ' \
  "${repo_root}/.github/workflows/build.yml" \
  "${repo_root}/.github/workflows/promote.yml")"
if grep -Fv -- '--new-bundle-format=false' <<<"${container_cosign_commands}" >/dev/null; then
  echo 'Cosign 3 container operations must preserve sigstore attachments explicitly' >&2
  exit 1
fi

if rg -n --glob '!tests/test-release-contracts.sh' -- '--output-signature' \
    "${repo_root}/.github" "${repo_root}/tools" "${repo_root}/docs" >/dev/null; then
  echo 'Cosign 3 blob signing must not use the deprecated detached-signature output' >&2
  exit 1
fi
grep -Fq -- "--bundle \"\${iso}.sigstore.json\"" \
  "${repo_root}/.github/workflows/release.yml"
grep -Fq 'cosign verify-blob' "${repo_root}/.github/workflows/release.yml"
grep -Fq -- "--bundle \"\${artifact_dir}/\${iso_name}.sigstore.json\"" \
  "${repo_root}/tools/generate-release-artifacts.sh"

grep -Fqx 'net.waterfox.waterfox' "${repo_root}/repo_files/flatpaks"
if [[ -e "${repo_root}/build_files/waterfox-installer.sh" ]]; then
  echo 'Waterfox must be delivered through the signed Flatpak repository.' >&2
  exit 1
fi

if rg -n -- '--nogpgcheck|--skip-unavailable' "${repo_root}/build_files" >/dev/null; then
  echo 'image package installation must not bypass signatures or missing packages' >&2
  exit 1
fi

if rg -n -i --glob '!tests/test-release-contracts.sh' \
    'derrik|soltros/random-stuff|github\.com/soltros/|ghcr\.io/soltros/' \
    "${repo_root}" >/dev/null; then
  echo 'legacy author identities and package sources must not appear in Reborn artifacts' >&2
  exit 1
fi

printf 'PASS: unpublished release and reproducible source contracts\n'
