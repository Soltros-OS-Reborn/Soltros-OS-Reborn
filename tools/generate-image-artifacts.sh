#!/usr/bin/env bash

set -euo pipefail

image_ref="${1:?usage: generate-image-artifacts.sh IMAGE OUTPUT_DIR}"
output_dir="${2:?usage: generate-image-artifacts.sh IMAGE OUTPUT_DIR}"
podman_command="${PODMAN:-podman}"
mkdir -p "${output_dir}"

safe_name="$(printf '%s' "${image_ref}" | tr '/:@' '----')"
inspect_file="${output_dir}/${safe_name}.inspect.json"
packages_file="$(mktemp /tmp/soltros-image-packages-XXXXXX)"
trap 'rm -f "${packages_file}"' EXIT

"${podman_command}" inspect "${image_ref}" > "${inspect_file}"
"${podman_command}" run --rm --entrypoint /usr/bin/rpm "${image_ref}" \
  -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\n' | sort -u > "${packages_file}"

created="$(jq -r '.[0].Created // "1970-01-01T00:00:00Z"' "${inspect_file}")"
digest="$(jq -r '.[0].Digest // (.[0].RepoDigests[0] // "unknown")' "${inspect_file}")"

jq -Rn \
  --arg image "${image_ref}" \
  --arg created "${created}" \
  '[inputs | split("\t") | {name:.[0],versionInfo:.[1],supplier:("Organization: Fedora"),downloadLocation:"NOASSERTION",filesAnalyzed:false,SPDXID:("SPDXRef-Package-"+(.[0]|gsub("[^A-Za-z0-9.-]";"-"))+"-"+(input_line_number|tostring))}] as $packages |
   {spdxVersion:"SPDX-2.3",dataLicense:"CC0-1.0",SPDXID:"SPDXRef-DOCUMENT",name:$image,documentNamespace:("https://soltros.dev/spdx/image/"+($image|@uri)),creationInfo:{created:$created,creators:["Tool: SoltrOS image artifact generator"]},packages:$packages}' \
  < "${packages_file}" > "${output_dir}/${safe_name}.spdx.json"

jq -S -n \
  --arg image "${image_ref}" \
  --arg digest "${digest}" \
  --arg revision "${GITHUB_SHA:-unknown}" \
  --arg run_id "${GITHUB_RUN_ID:-local}" \
  '{_type:"https://in-toto.io/Statement/v1",subject:[{name:$image,digest:{container:$digest}}],predicateType:"https://slsa.dev/provenance/v1",predicate:{buildDefinition:{buildType:"https://soltros.dev/build/bootc",externalParameters:{revision:$revision}},runDetails:{builder:{id:"https://github.com/actions/runner"},metadata:{invocationId:$run_id}}}}' \
  > "${output_dir}/${safe_name}.provenance.json"

printf 'IMAGE_ARTIFACTS=%s\n' "${output_dir}"
