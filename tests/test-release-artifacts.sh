#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/soltros-release-artifacts-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
iso="${test_root}/SoltrOS-test-live-x86_64.iso"
payload="${test_root}/payload"
artifacts="${test_root}/artifacts"
signed_artifacts="${test_root}/signed-artifacts"
fake_cosign="${test_root}/cosign"
cosign_log="${test_root}/cosign.log"
mkdir -p "${payload}"
printf '%s\n' 'synthetic ISO fixture' > "${iso}"
jq -n '{schema_version:1,build_id:"fixture",image_count:4,unique_blob_count:8,unique_blob_bytes:1024}' > "${payload}/inventory.json"

SOLTROS_OFFLINE_PAYLOAD_DIR="${payload}" BUILD_ID=fixture \
  "${repo_root}/tools/generate-release-artifacts.sh" "${iso}" "${artifacts}" >/dev/null

(cd "${artifacts}" && sha256sum --check "$(basename "${iso}").sha256") >/dev/null
jq -e '.spdxVersion == "SPDX-2.3" and (.packages | length == 1)' \
  "${artifacts}/$(basename "${iso}").spdx.json" >/dev/null
jq -e '._type == "https://in-toto.io/Statement/v1"' \
  "${artifacts}/$(basename "${iso}").provenance.json" >/dev/null
jq -e '.image_count == 4 and .unique_blob_count == 8' \
  "${artifacts}/$(basename "${iso}").inventory.json" >/dev/null
jq -e '.variants | length == 4' "${artifacts}/release-index.json" >/dev/null
test -s "${artifacts}/$(basename "${iso}").signature-status"

cat > "${fake_cosign}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command_name="${1:?missing command}"
shift
printf '%s %s\n' "${command_name}" "$*" >> "${COSIGN_LOG:?}"
case "${command_name}" in
  sign-blob)
    while [[ "$#" -gt 0 ]]; do
      if [[ "$1" == --bundle ]]; then
        printf '%s\n' '{"mediaType":"application/vnd.dev.sigstore.bundle.v0.3+json"}' > "$2"
        exit 0
      fi
      shift
    done
    exit 2
    ;;
  verify-blob)
    while [[ "$#" -gt 0 ]]; do
      if [[ "$1" == --bundle ]]; then
        test -s "$2"
        exit
      fi
      shift
    done
    exit 2
    ;;
  *)
    exit 2
    ;;
esac
EOF
chmod 0755 "${fake_cosign}"

COSIGN="${fake_cosign}" COSIGN_LOG="${cosign_log}" \
COSIGN_PRIVATE_KEY=fixture COSIGN_PASSWORD=fixture \
SOLTROS_OFFLINE_PAYLOAD_DIR="${payload}" BUILD_ID=fixture \
  "${repo_root}/tools/generate-release-artifacts.sh" \
    "${iso}" "${signed_artifacts}" >/dev/null

bundle="${signed_artifacts}/$(basename "${iso}").sigstore.json"
test -s "${bundle}"
jq -e --arg bundle "$(basename "${bundle}")" \
  '.iso.signature == $bundle and (.artifacts | index($bundle)) != null' \
  "${signed_artifacts}/release-index.json" >/dev/null
grep -Fq 'sign-blob --yes --key env://COSIGN_PRIVATE_KEY --bundle' "${cosign_log}"
grep -Fq 'verify-blob --key' "${cosign_log}"

printf 'PASS: LiveISO release artifact set contains checksum, Sigstore bundle hook, SPDX, provenance, and inventory\n'
