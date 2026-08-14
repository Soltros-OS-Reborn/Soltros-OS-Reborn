# SoltrOS Reborn Architecture and Delivery Roadmap

This file is the execution ledger for the Reborn architecture work. Phases 0-5
track implemented source contracts. Runtime and release validation remains
separate in Phase 6 and Runtime Evidence.

## Non-Negotiable Product Contracts

- [x] Record that no SoltrOS Reborn image has been published to GitHub Container
  Registry yet. Existing package references must not be treated as available
  Reborn releases or used as offline installation sources.
- [x] Define the LiveISO as a complete, usable offline SoltrOS environment rather
  than an installer-only boot image.
- [x] Require the LiveISO to install KDE Plasma, GNOME, Niri with Dank Material
  Shell, or Niri with Noctalia without network access.
- [x] Allow the installer to check for and download newer signed content only when
  networking is available and the user explicitly opts in. Offline installation
  remains the default and must never be blocked by update availability.
- [x] Preserve one independently updateable bootc image per desktop variant.

## Phase 0: Baseline and Tracking

- [x] Create this implementation ledger before architecture changes.
- [x] Capture the current source, image, installer, and CI contracts as executable
  baseline tests.
- [x] Add a single local task interface for validation, image builds, disk images,
  ISO builds, and VM QA.

## Phase 1: Release Metadata and Reproducibility

- [x] Add a validated release manifest for Fedora version, image namespace,
  channels, source digests, and installer metadata.
- [x] Remove duplicated hard-coded Fedora versions, image references, and variant
  counts from build scripts, CI, installer configuration, and documentation.
- [x] Generate the image matrix, signing policy, installer catalog, and release
  metadata from validated manifests.
- [x] Pin every downloaded build input or verify it with a committed checksum.
- [x] Remove mutable build-time downloads and prohibit unsigned RPM installation.

## Phase 2: Runtime Update and Trust Model

- [x] Make `soltros status`, `soltros update`, and `soltros rollback` use bootc as
  the authoritative operating-system deployment interface.
- [x] Report component update failures accurately instead of hiding them behind a
  successful aggregate result.
- [x] Merge SoltrOS image trust into the base containers policy without blocking
  normal Podman, Toolbox, or Distrobox image pulls.
- [x] Add signing-key rotation support and verify the effective trust policy.
- [x] Add `soltros doctor` and a redacted diagnostic-report command.

## Phase 3: Image Structure and Build Integrity

- [x] Separate core, hardware, gaming, desktop, and optional application package
  contracts.
- [x] Remove duplicated desktop packages and move suitable GUI applications to
  declarative Flatpak or optional first-boot profiles.
- [x] Make required packages, the selected kernel, initramfs generation, enabled
  services, display managers, sessions, and portals fail-closed.
- [x] Run `bootc container lint` for every image.
- [x] Establish a genuinely shared base-layer strategy or document and test the
  deliberate Fedora Kinoite, Silverblue, and minimal bootc base split.
- [x] Add versioned user-default migration that backs up and preserves existing
  Niri, DMS, Noctalia, shell, and shortcut customizations.

## Phase 4: Offline LiveISO and Installer

- [x] Build a complete graphical Live environment with networking, audio,
  Bluetooth, graphics, storage, terminal, browser, and hardware diagnostics.
- [x] Store all four installable bootc variants in one deduplicated local OCI
  layout on the ISO and verify that no registry access is required.
- [x] Provide a graphical installer flow for locale, keyboard, timezone, desktop
  variant, storage, encryption, user, hostname, and final confirmation.
- [x] Present an optional, default-off online-update choice only after network and
  signature preflight succeeds.
- [x] Install the embedded digest when offline; when opted in, install a newer
  verified digest while retaining the selected stable update reference.
- [x] Record selected variant, source digest, update reference, build identifier,
  and installation mode on the installed system.
- [x] Make cancellation and failure leave disks, mounts, temporary containers,
  and installer state in a documented recoverable condition.
- [x] Produce checksum, signature, SBOM, provenance, and embedded-image inventory
  artifacts for the ISO.

## Phase 5: CI, Channels, and Publication

- [x] Add a fast validation job before image matrix builds.
- [x] Build, inspect, and smoke-test all four images on pull requests without
  publishing them as Reborn releases.
- [x] Add immutable build tags and explicit `testing`, `stable`, and `latest`
  promotion rules.
- [x] Push to a temporary digest, sign and verify it, then promote release tags.
- [x] Generate and attach SPDX SBOM and build provenance for every OCI image.
- [x] Publish the offline LiveISO through a durable release surface rather than a
  short-lived CI artifact.
- [x] Keep publication disabled until the repository owner explicitly enables the
  Reborn package namespace and release credentials.

## Phase 6: End-to-End QA and Release Gate

- [ ] Boot the LiveISO in UEFI and legacy-compatible modes where supported.
- [ ] Verify the full live desktop without network access.
- [ ] Install each desktop variant offline to a fresh virtual disk, reboot, and
  verify the expected display manager, session, portals, services, and commands.
- [ ] Verify the opt-in online-update path independently from offline installation.
- [ ] Verify encrypted storage, cancellation, retry, disk-selection protection,
  Secure Boot expectations, and rollback.
- [ ] Verify local and CI builds from a clean checkout and document exact release
  and rollback procedures.

## Runtime Evidence

- [x] Boot the Fedora 44 LiveISO through UEFI with SELinux enforcing and reach an
  automatically logged-in KDE Plasma session. Evidence:
  `output/qa/live-uefi-offline-final/desktop-qa5.png`.
- [x] Boot the LiveISO with `-nic none` and confirm through the QEMU monitor that
  no network backend or PCI network controller is present.
- [x] Launch the installer from the liveuser session and render all four
  manifest-backed desktop choices without truncation. Evidence:
  `output/qa/live-uefi-offline-final/selector-qa6.png`.
- [x] Verify the selected embedded KDE OCI digest and generate
  `installation.json` and `installation.ks` under the liveuser runtime directory
  without registry access.
- [x] Start Fedora's `liveinst` wrapper and reach the interactive Anaconda Web UI
  welcome page. Evidence:
  `output/qa/live-uefi-offline-final/anaconda-ready-qa6.png`.
- [ ] Complete an offline installation of each variant to a fresh virtual disk,
  reboot it, and verify its display manager, session, portals, services, and
  update metadata.
- [ ] Verify legacy-compatible boot, encrypted storage, cancellation, retry, and
  the explicit online-update path.

## Decision Record

- **2026-08-11:** Reborn images are not yet published. Registry references in the
  source are development targets, not evidence of available Reborn packages.
- **2026-08-11:** The final LiveISO must be offline-first and fully usable. A thin
  network installer alone does not satisfy the product contract.
- **2026-08-11:** Online installation updates are optional, explicit, signed, and
  default off.
