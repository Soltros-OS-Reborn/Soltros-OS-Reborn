#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
iso_argument="${1:?usage: generate-release-artifacts.sh ISO [OUTPUT_DIR]}"
artifact_dir="${2:-$(dirname -- "${iso_argument}")/release-artifacts}"
release_manifest="${repo_root}/release/release.json"
variant_manifest="${repo_root}/variants/desktop-variants.json"
payload_dir="${SOLTROS_OFFLINE_PAYLOAD_DIR:-}"
media_profile="${LIVEISO_PROFILE:-online}"
iso_path="$(realpath "${iso_argument}")"
artifact_dir="$(realpath -m "${artifact_dir}")"

[[ -s "${iso_path}" ]] || { echo "ISO is missing or empty: ${iso_path}" >&2; exit 1; }
mkdir -p "${artifact_dir}"
iso_name="$(basename -- "${iso_path}")"
sha256sum "${iso_path}" > "${artifact_dir}/${iso_name}.sha256"

build_id="${BUILD_ID:-$(git -C "${repo_root}" rev-parse --verify HEAD 2>/dev/null || printf unknown)}"
iso_digest="$(sha256sum "${iso_path}" | awk '{print $1}')"
if [[ -n "${COSIGN_PRIVATE_KEY:-}" && -n "${COSIGN_PASSWORD:-}" && -n "${COSIGN:-}" ]]; then
  signature_artifact="${iso_name}.sigstore.json"
else
  signature_artifact="${iso_name}.signature-status"
fi

jq -S -n \
  --arg name "${iso_name}" \
  --arg digest "sha256:${iso_digest}" \
  --arg build_id "${build_id}" \
  '{spdxVersion:"SPDX-2.3",dataLicense:"CC0-1.0",SPDXID:"SPDXRef-DOCUMENT",name:$name,documentNamespace:("https://soltros.dev/spdx/"+$build_id),creationInfo:{created:"1970-01-01T00:00:00Z",creators:["Tool: SoltrOS release tooling"]},packages:[{SPDXID:"SPDXRef-Package-LiveISO",name:$name,versionInfo:$build_id,downloadLocation:"NOASSERTION",checksums:[{algorithm:"SHA256",checksumValue:($digest|sub("^sha256:";""))}]}]}' \
  > "${artifact_dir}/${iso_name}.spdx.json"

jq -S -n \
  --arg subject "${iso_name}" \
  --arg digest "sha256:${iso_digest}" \
  --arg build_id "${build_id}" \
  --arg source "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-soltros-os-reborn/soltros-os-reborn}" \
  '{_type:"https://in-toto.io/Statement/v1",subject:[{name:$subject,digest:{sha256:($digest|sub("^sha256:";""))}}],predicateType:"https://slsa.dev/provenance/v1",predicate:{buildDefinition:{buildType:"https://soltros.dev/build/liveiso",externalParameters:{build_id:$build_id,source:$source}},runDetails:{builder:{id:"https://github.com/actions/runner"},metadata:{invocationId:$build_id}}}}' \
  > "${artifact_dir}/${iso_name}.provenance.json"

if [[ -n "${payload_dir}" && -f "${payload_dir}/inventory.json" ]]; then
  cp "${payload_dir}/inventory.json" "${artifact_dir}/${iso_name}.inventory.json"
else
  jq -S -n --arg build_id "${build_id}" --argjson variants "$(jq 'length' "${variant_manifest}")" \
    '{schema_version:1,build_id:$build_id,image_count:$variants,unique_blob_count:0,unique_blob_bytes:0,status:"inventory-not-attached"}' \
    > "${artifact_dir}/${iso_name}.inventory.json"
fi

jq -S -n \
  --arg iso "${iso_name}" \
  --arg digest "sha256:${iso_digest}" \
  --arg build_id "${build_id}" \
  --arg signature "${signature_artifact}" \
  --arg media_profile "${media_profile}" \
  --arg selected_variant "${media_profile}" \
  --slurpfile release "${release_manifest}" \
  --slurpfile variants "${variant_manifest}" \
  '{schema_version:1,product:$release[0].product,build_id:$build_id,media_profile:$media_profile,iso:{name:$iso,digest:$digest,checksum:($iso+".sha256"),signature:$signature},variants:($variants[0]|if $selected_variant == "online" then map({id,display_name,image_name}) else map(select(.id == $selected_variant) | {id,display_name,image_name}) end),publication:$release[0].publication,artifacts:[($iso+".sha256"),$signature,($iso+".spdx.json"),($iso+".provenance.json"),($iso+".inventory.json")]}' \
  > "${artifact_dir}/release-index.json"

if [[ -n "${COSIGN_PRIVATE_KEY:-}" && -n "${COSIGN_PASSWORD:-}" && -n "${COSIGN:-}" ]]; then
  "${COSIGN}" sign-blob --use-signing-config=false --yes --key env://COSIGN_PRIVATE_KEY --bundle "${artifact_dir}/${iso_name}.sigstore.json" "${iso_path}"
  "${COSIGN}" verify-blob --key "${repo_root}/soltros.pub" --bundle "${artifact_dir}/${iso_name}.sigstore.json" "${iso_path}"
else
  printf '%s\n' 'ISO signature not generated: configure COSIGN, COSIGN_PRIVATE_KEY, and COSIGN_PASSWORD in the release job.' > "${artifact_dir}/${iso_name}.signature-status"
fi

printf 'RELEASE_ARTIFACTS=%s\n' "${artifact_dir}"
