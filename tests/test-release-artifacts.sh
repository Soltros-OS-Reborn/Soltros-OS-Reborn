#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/soltros-release-artifacts-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
iso="${test_root}/SoltrOS-test-live-x86_64.iso"
payload="${test_root}/payload"
artifacts="${test_root}/artifacts"
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

printf 'PASS: LiveISO release artifact set contains checksum, signature hook, SPDX, provenance, and inventory\n'
