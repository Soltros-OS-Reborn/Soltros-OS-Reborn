#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-${repo_root}/output/offline-payload}"
variant_manifest="${repo_root}/variants/desktop-variants.json"
release_manifest="${repo_root}/release/release.json"
registry="${IMAGE_REGISTRY:-localhost/soltros-reborn}"
tag="${IMAGE_TAG:-dev}"
skopeo_command="${SKOPEO:-skopeo}"
offline_variant="${OFFLINE_VARIANT:-}"

registry="${registry,,}"
registry="${registry%/}"
output_parent="$(dirname -- "${output_dir}")"
mkdir -p "${output_parent}"
output_parent="$(cd -- "${output_parent}" && pwd)"
output_dir="${output_parent}/$(basename -- "${output_dir}")"
work_dir="$(mktemp -d "${output_parent}/.offline-payload-XXXXXX")"
trap 'rm -rf "${work_dir}"' EXIT

layout="${work_dir}/oci"
mkdir -p "${layout}"

release_version="$(jq -er '.product.release_version' "${release_manifest}")"
stable_tag="$(jq -er '.channels.stable' "${release_manifest}")"
payload_path="$(jq -er '.installer.payload_path' "${release_manifest}")"
target_registry="$(jq -er '.publication.registry' "${release_manifest}")"
online_updates_available="$(jq -r '.publication.enabled and .publication.repository_ready' "${release_manifest}")"
build_id="${BUILD_ID:-}"
if [[ -z "${build_id}" ]]; then
  source_revision="$(git -C "${repo_root}" rev-parse --verify HEAD 2>/dev/null || printf unknown)"
  build_id="${release_version}-${source_revision:0:12}"
fi

catalog_entries="${work_dir}/catalog-entries.jsonl"
: > "${catalog_entries}"

if [[ -n "${offline_variant}" ]] && ! jq -e --arg variant "${offline_variant}" \
    'any(.[]; .id == $variant)' "${variant_manifest}" >/dev/null; then
  echo "Unknown offline payload variant: ${offline_variant}" >&2
  exit 1
fi

variant_filter='.'
if [[ -n "${offline_variant}" ]]; then
  variant_filter='map(select(.id == $variant))'
fi

while IFS=$'\t' read -r variant display_name image_name; do
  source_ref="${registry}/${image_name}:${tag}"
  if ! "${skopeo_command}" inspect "containers-storage:${source_ref}" >/dev/null; then
    echo "Local desktop image is unavailable: ${source_ref}" >&2
    exit 1
  fi

  "${skopeo_command}" copy \
    "containers-storage:${source_ref}" \
    "oci:${layout}:${variant}" >/dev/null

  digest="$("${skopeo_command}" inspect --format '{{.Digest}}' "oci:${layout}:${variant}")"
  if [[ ! "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "OCI manifest digest is invalid for ${variant}: ${digest}" >&2
    exit 1
  fi

  jq -cn \
    --arg variant "${variant}" \
    --arg display_name "${display_name}" \
    --arg source_ref "oci:${payload_path}/oci:${variant}" \
    --arg source_digest "${digest}" \
    --arg update_ref "${target_registry}/${image_name}:${stable_tag}" \
    --argjson online_updates_available "${online_updates_available}" \
    '{
      variant: $variant,
      display_name: $display_name,
      source_ref: $source_ref,
      source_digest: $source_digest,
      update_ref: $update_ref,
      online_updates_available: $online_updates_available
    }' >> "${catalog_entries}"
done < <(jq -r --arg variant "${offline_variant}" \
  "${variant_filter}[] | [.id, .display_name, .image_name] | @tsv" \
  "${variant_manifest}")

jq -s \
  --arg build_id "${build_id}" \
  --arg payload_path "${payload_path}" \
  '{
    schema_version: 1,
    build_id: $build_id,
    payload_path: $payload_path,
    variant_count: length,
    variants: .
  }' "${catalog_entries}" > "${work_dir}/catalog.json"

blob_count="$(find "${layout}/blobs/sha256" -maxdepth 1 -type f | wc -l)"
blob_bytes="$(find "${layout}/blobs/sha256" -maxdepth 1 -type f -printf '%s\n' | awk '{ total += $1 } END { print total + 0 }')"
jq -n \
  --arg build_id "${build_id}" \
  --argjson image_count "$(jq '.variants | length' "${work_dir}/catalog.json")" \
  --argjson blob_count "${blob_count}" \
  --argjson blob_bytes "${blob_bytes}" \
  '{
    schema_version: 1,
    build_id: $build_id,
    image_count: $image_count,
    unique_blob_count: $blob_count,
    unique_blob_bytes: $blob_bytes
  }' > "${work_dir}/inventory.json"

rm -rf "${output_dir}/oci"
mkdir -p "${output_dir}"
mv "${work_dir}/oci" "${output_dir}/oci"
mv "${work_dir}/catalog.json" "${output_dir}/catalog.json"
mv "${work_dir}/inventory.json" "${output_dir}/inventory.json"

printf 'PAYLOAD=%s\n' "${output_dir}"
printf 'CATALOG=%s\n' "${output_dir}/catalog.json"
printf 'INVENTORY=%s\n' "${output_dir}/inventory.json"
