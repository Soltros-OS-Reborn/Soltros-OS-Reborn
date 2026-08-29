set shell := ["bash", "-euo", "pipefail", "-c"]

manifest := "variants/desktop-variants.json"
release_manifest := "release/release.json"
default_variant := "kde"
default_tag := env("IMAGE_TAG", "dev")
default_registry := env("IMAGE_REGISTRY", "localhost/soltros-reborn")

default:
    @just --list

# Run source-level project contracts.
test:
    @for command_name in jq rg; do \
      command -v "${command_name}" >/dev/null || { \
        printf 'Required validation command is missing: %s\n' "${command_name}" >&2; \
        exit 1; \
      }; \
    done
    @for test_script in tests/*.sh; do "${test_script}"; done

# Run the local source validation gate.
validate: test
    @tools/validate-release.sh
    @tools/generate-release-assets.sh --check
    @scripts="$(find build_files disk_config resources system_files tests tools -type f -name '*.sh' -print)"; \
      if [[ -n "${scripts}" ]]; then shellcheck --exclude=SC1091 ${scripts}; fi
    @git diff --check
    @rg -n -P '[\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{F900}-\x{FAFF}]' \
      --hidden -g '!.git' . >/tmp/soltros-chinese-scan && { \
        cat /tmp/soltros-chinese-scan; \
        rm -f /tmp/soltros-chinese-scan; \
        exit 1; \
      } || { status=$?; rm -f /tmp/soltros-chinese-scan; [[ $status -eq 1 ]]; }
    @tools/actionlint.sh

# Regenerate all manifest-derived release assets.
generate-release-assets:
    @tools/generate-release-assets.sh

# Build one desktop image from the variant manifest.
build-image variant=default_variant tag=default_tag registry=default_registry:
    #!/usr/bin/env bash
    variant_data="$(jq -cer --arg id "{{ variant }}" '.[] | select(.id == $id)' "{{ manifest }}")"
    base_image="$(jq -r '.base_image' <<<"${variant_data}")"
    base_digest="$(jq -r '.base_digest' <<<"${variant_data}")"
    image_name="$(jq -r '.image_name' <<<"${variant_data}")"
    fedora_version="$(jq -er '.product.fedora_version' "{{ release_manifest }}")"
    kernel_package="$(jq -er '.kernel.package' "{{ release_manifest }}")"
    podman build \
      --build-arg "BASE_REF=${base_image}@${base_digest}" \
      --build-arg "DESKTOP_VARIANT={{ variant }}" \
      --build-arg "FEDORA_VERSION=${fedora_version}" \
      --build-arg "KERNEL_PACKAGE=${kernel_package}" \
      --tag "{{ registry }}/${image_name}:{{ tag }}" \
      .

# Build every desktop image from the variant manifest.
build-images tag=default_tag registry=default_registry:
    @while IFS= read -r variant; do \
      just build-image "${variant}" "{{ tag }}" "{{ registry }}"; \
    done < <(jq -r '.[].id' "{{ manifest }}")

# Build one deduplicated offline OCI payload from all desktop images.
build-offline-payload output="output/offline-payload" tag=default_tag registry=default_registry:
    IMAGE_REGISTRY="{{ registry }}" IMAGE_TAG="{{ tag }}" \
      disk_config/build-offline-payload.sh "{{ output }}"

# Build one online or desktop-specific LiveISO from locally available images.
build-liveiso output="output/liveiso" profile="online" tag=default_tag registry=default_registry:
    IMAGE_REGISTRY="{{ registry }}" IMAGE_TAG="{{ tag }}" LIVEISO_PROFILE="{{ profile }}" \
      disk_config/build-live-iso.sh "{{ output }}" "{{ profile }}"

# Boot an ISO with KVM/QEMU. Add extra QEMU options through QEMU_EXTRA_ARGS.
run-liveiso iso="output/liveiso/SoltrOS-dev-online-x86_64.iso" memory="8G" cpus="4":
    #!/usr/bin/env bash
    [[ -f "{{ iso }}" ]] || { echo "ISO does not exist: {{ iso }}" >&2; exit 1; }
    read -r -a extra_args <<<"${QEMU_EXTRA_ARGS:-}"
    qemu-system-x86_64 \
      -enable-kvm \
      -machine q35,accel=kvm \
      -cpu host \
      -smp "{{ cpus }}" \
      -m "{{ memory }}" \
      -boot d \
      -cdrom "{{ iso }}" \
      "${extra_args[@]}"
