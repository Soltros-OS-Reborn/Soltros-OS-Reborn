#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d /tmp/soltros-offline-payload-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT
fake_skopeo="${test_root}/skopeo"

cat > "${fake_skopeo}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == inspect && "${2:-}" == --format ]]; then
  ref="$4"
  variant="${ref##*:}"
  printf 'sha256:%064x\n' "$(( ${#variant} + 1 ))"
  exit 0
fi

if [[ "$1" == inspect ]]; then
  printf '{}\n'
  exit 0
fi

if [[ "$1" == copy ]]; then
  destination="$3"
  path="${destination#oci:}"
  path="${path%:*}"
  mkdir -p "${path}/blobs/sha256"
  printf '%s\n' "$2" > "${path}/blobs/sha256/shared"
  printf '{"imageLayoutVersion":"1.0.0"}\n' > "${path}/oci-layout"
  printf '{"schemaVersion":2,"manifests":[]}\n' > "${path}/index.json"
  exit 0
fi

exit 2
EOF
chmod 0755 "${fake_skopeo}"

BUILD_ID=test-build \
IMAGE_REGISTRY=registry.example.test/soltros \
IMAGE_TAG=test \
SKOPEO="${fake_skopeo}" \
  "${repo_root}/disk_config/build-offline-payload.sh" "${test_root}/payload" >/dev/null

jq -e '
  .schema_version == 1 and
  .build_id == "test-build" and
  .payload_path == "/usr/share/soltros/installer" and
  (.variants | length == 4) and
  all(.variants[];
    (.source_ref | startswith("oci:/usr/share/soltros/installer/oci:")) and
    (.source_digest | test("^sha256:[0-9a-f]{64}$")) and
    (.update_ref | startswith("ghcr.io/soltros-os-reborn/")) and
    (.update_ref | endswith(":stable")) and
    (.online_updates_available == true))
' "${test_root}/payload/catalog.json" >/dev/null

jq -e '
  .schema_version == 1 and
  .build_id == "test-build" and
  .image_count == 4 and
  .unique_blob_count == 1
' "${test_root}/payload/inventory.json" >/dev/null

[[ -f "${test_root}/payload/oci/oci-layout" ]]
[[ -f "${test_root}/payload/oci/index.json" ]]

printf 'PASS: four desktop images share one offline OCI content store\n'
