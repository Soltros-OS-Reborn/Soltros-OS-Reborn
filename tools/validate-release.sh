#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
release_manifest="${repo_root}/release/release.json"
source_lock="${repo_root}/release/sources.lock.json"
variant_manifest="${repo_root}/variants/desktop-variants.json"
fedora_version="$(jq -er '.product.fedora_version | tostring' "${release_manifest}")"

jq -e '
  .schema_version == 1 and
  (.product.id | type == "string" and length > 0) and
  (.product.fedora_version | type == "number") and
  (.product.architectures == ["x86_64"]) and
  (.publication.enabled | type == "boolean") and
  (.publication.repository_ready | type == "boolean") and
  (.publication.registry | test("^[a-z0-9.-]+/[a-z0-9._/-]+$")) and
  (.trust.public_key_sha256 | test("^[0-9a-f]{64}$")) and
  (.trust.key_paths | length >= 1) and
  all(.trust.key_paths[]; startswith("/usr/share/pki/containers/")) and
  (.kernel.package | test("^kernel-[a-z0-9-]+$")) and
  (.channels.latest == "latest") and
  (.channels.default == .channels.stable) and
  (.installer.offline_required == true) and
  (.installer.payload_path | startswith("/usr/share/soltros/")) and
  (.installer.online_update_default == false) and
  (.installer.online_update_requires_consent == true)
' "${release_manifest}" >/dev/null

expected_public_key_sha256="$(jq -er '.trust.public_key_sha256' "${release_manifest}")"
actual_public_key_sha256="$(sha256sum "${repo_root}/soltros.pub" | awk '{print $1}')"
if [[ "${actual_public_key_sha256}" != "${expected_public_key_sha256}" ]]; then
  echo 'Committed signing public key does not match the release manifest fingerprint.' >&2
  exit 1
fi

jq -e '
  .schema_version == 1 and
  (.bootc_image_builder.digest | test("^sha256:[0-9a-f]{64}$")) and
  (.live_media_builder.digest | test("^sha256:[0-9a-f]{64}$")) and
  (.live_media_builder.packages == ["lorax-lmc-novirt"]) and
  (.actionlint.linux_amd64_sha256 | test("^[0-9a-f]{64}$")) and
  (.actionlint.linux_arm64_sha256 | test("^[0-9a-f]{64}$")) and
  (.starship.x86_64_unknown_linux_gnu_sha256 | test("^[0-9a-f]{64}$")) and
  (.starship.aarch64_unknown_linux_musl_sha256 | test("^[0-9a-f]{64}$")) and
  (.mbpfan.source_sha256 | test("^[0-9a-f]{64}$")) and
  (.nix_installer.script_sha256 | test("^[0-9a-f]{64}$")) and
  (.homebrew_installer.commit | test("^[0-9a-f]{40}$")) and
  (.homebrew_installer.script_sha256 | test("^[0-9a-f]{64}$")) and
  (.oh_my_zsh_installer.commit | test("^[0-9a-f]{40}$")) and
  (.oh_my_zsh_installer.script_sha256 | test("^[0-9a-f]{64}$")) and
  (.shell_assets.bass_python_sha256 | test("^[0-9a-f]{64}$")) and
  (.shell_assets.bass_fish_sha256 | test("^[0-9a-f]{64}$")) and
  (.shell_assets.grc_fish_sha256 | test("^[0-9a-f]{64}$"))
' "${source_lock}" >/dev/null

jq -e --arg fedora_version "${fedora_version}" '
  length == 4 and
  ([.[].id] | unique | length == length) and
  ([.[].image_name] | unique | length == length) and
  all(.[];
    (.base_tag == $fedora_version) and
    (.base_digest | test("^sha256:[0-9a-f]{64}$"))
  )
' "${variant_manifest}" >/dev/null

live_variant="$(jq -er '.installer.live_variant' "${release_manifest}")"
jq -e --arg live_variant "${live_variant}" \
  'any(.[]; .id == $live_variant)' "${variant_manifest}" >/dev/null

if jq -e '.publication.enabled and (.publication.repository_ready | not)' \
    "${release_manifest}" >/dev/null; then
  echo 'Publication cannot be enabled before the package repository is ready.' >&2
  exit 1
fi

printf 'PASS: release, source-lock, and desktop variant manifests\n'
