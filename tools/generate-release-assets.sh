#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
release_manifest="${repo_root}/release/release.json"
variant_manifest="${repo_root}/variants/desktop-variants.json"
generated_dir="${repo_root}/release/generated"
mode="${1:-write}"

if [[ "${mode}" != write && "${mode}" != --check ]]; then
  echo 'Usage: generate-release-assets.sh [--check]' >&2
  exit 2
fi

work_dir="$(mktemp -d /tmp/soltros-release-assets-XXXXXX)"
trap 'rm -rf "${work_dir}"' EXIT
mkdir -p "${work_dir}/generated"

jq -S -n \
  --slurpfile release "${release_manifest}" \
  --slurpfile variants "${variant_manifest}" \
  '{
    schema_version: 1,
    product: $release[0].product,
    publication: $release[0].publication,
    trust: $release[0].trust,
    channels: $release[0].channels,
    installer: $release[0].installer,
    variant_count: ($variants[0] | length),
    variants: $variants[0]
  }' > "${work_dir}/generated/release-metadata.json"

jq -S -n --slurpfile variants "${variant_manifest}" \
  '{desktop: $variants[0]}' > "${work_dir}/generated/desktop-matrix.json"

jq -S -n \
  --slurpfile release "${release_manifest}" \
  --slurpfile variants "${variant_manifest}" \
  '{
    schema_version: 1,
    payload_path: $release[0].installer.payload_path,
    live_variant: $release[0].installer.live_variant,
    media_profiles: $release[0].installer.media_profiles,
    offline_required: $release[0].installer.offline_required,
    online_update_default: $release[0].installer.online_update_default,
    online_update_requires_consent: $release[0].installer.online_update_requires_consent,
    publication_enabled: ($release[0].publication.enabled and $release[0].publication.repository_ready),
    registry: $release[0].publication.registry,
    stable_channel: $release[0].channels.stable,
    variant_count: ($variants[0] | length)
  }' > "${work_dir}/generated/installer-profile.json"

jq -S -n \
  --slurpfile release "${release_manifest}" \
  --slurpfile variants "${variant_manifest}" '
    ($release[0].publication.registry) as $registry |
    ($release[0].trust.key_paths) as $key_paths |
    {
      default: [{type: "insecureAcceptAnything"}],
      transports: {
        docker: (reduce $variants[0][].image_name as $image (
          {};
          .[$registry + "/" + $image] = [{
            type: "sigstoreSigned",
            keyPaths: $key_paths,
            signedIdentity: {type: "matchRepository"}
          }]
        )),
        "docker-daemon": {"": [{type: "insecureAcceptAnything"}]}
      }
    }
  ' > "${work_dir}/policy.json"

jq -S -n --slurpfile release "${release_manifest}" '{
    schema_version: 1,
    immutable_tag_prefix: "sha-",
    automatic_channel: $release[0].channels.development,
    manual_transitions: [
      {from: $release[0].channels.development, to: $release[0].channels.testing},
      {from: $release[0].channels.testing, to: $release[0].channels.stable},
      {from: $release[0].channels.stable, to: $release[0].channels.latest}
    ]
  }' > "${work_dir}/generated/channel-policy.json"

registry="$(jq -er '.publication.registry' "${release_manifest}")"
{
  echo 'docker:'
  while IFS= read -r image_name; do
    printf '  %s/%s:\n' "${registry}" "${image_name}"
    echo '    use-sigstore-attachments: true'
  done < <(jq -r '.[].image_name' "${variant_manifest}")
} > "${work_dir}/generated/registries.yaml"

check_asset() {
  local generated="$1"
  local committed="$2"

  if [[ ! -f "${committed}" ]] || ! cmp -s "${generated}" "${committed}"; then
    echo "Generated release asset is stale: ${committed#"${repo_root}"/}" >&2
    diff -u "${committed}" "${generated}" 2>/dev/null || true
    return 1
  fi
}

if [[ "${mode}" == --check ]]; then
  check_asset "${work_dir}/policy.json" "${repo_root}/resources/policy.json"
  for asset in channel-policy.json desktop-matrix.json installer-profile.json registries.yaml release-metadata.json; do
    check_asset "${work_dir}/generated/${asset}" "${generated_dir}/${asset}"
  done
  echo 'PASS: generated release assets match their source manifests'
  exit 0
fi

mkdir -p "${generated_dir}"
install -m 0644 "${work_dir}/policy.json" "${repo_root}/resources/policy.json"
for asset in channel-policy.json desktop-matrix.json installer-profile.json registries.yaml release-metadata.json; do
  install -m 0644 "${work_dir}/generated/${asset}" "${generated_dir}/${asset}"
done

echo "GENERATED=${generated_dir}"
echo "POLICY=${repo_root}/resources/policy.json"
